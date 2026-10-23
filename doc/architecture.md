# 架构

YetEase 分成两层：**Rust 内核**负责协议、播放、队列、缓存等全部业务；**界面层**只负责显示和交互。桌面端用 Flutter，命令行直接链接内核。

```
┌────────────────────────── 界面层 ──────────────────────────┐
│  Flutter 应用（app/lib）            命令行（crates/ncm-cli）  │
│        │ flutter_rust_bridge                │ 直接调用        │
│  FFI 绑定（app/rust）                        │                │
└────────┼────────────────────────────────────┼───────────────┘
         ▼                                    ▼
┌──────────────────────── Rust 内核 ─────────────────────────┐
│  ncm-core   会话与设置持久化 · 播放队列 · 歌词 · 事件总线      │
│     ├── ncm-api     加密通道 · cookie 会话 · 各业务接口        │
│     └── ncm-player  symphonia 解码 · cpal 输出 · 边下边播      │
└────────────────────────────────────────────────────────────┘
```

## 目录

| 路径 | 内容 |
|---|---|
| `crates/ncm-api` | 网易云协议层，不依赖任何 UI，可单独作为库使用 |
| `crates/ncm-player` | 音频引擎 |
| `crates/ncm-core` | 业务核心，各端共用 |
| `crates/ncm-cli` | 命令行客户端（二进制名 `yetease`） |
| `app/rust` | 暴露给 Dart 的 FFI 层，只做类型转换 |
| `app/lib` | Flutter 界面 |
| `app/lib/src/rust` | flutter_rust_bridge 生成的 Dart 绑定，**不要手改** |

## ncm-api：协议层

请求按 api-enhanced（`util/request.js`、`util/crypto.js`）的行为用 Rust 重写，每个接口方法的注释里都写了对应的 api-enhanced 模块名，协议变化时可以直接对照。

| 通道 | 加密 | 地址 |
|---|---|---|
| weapi | 两次 AES-128-CBC + RSA（无填充）包装随机密钥 | `music.163.com/weapi/*` |
| eapi | `nobody{url}use{json}md5forencrypt` 摘要 + AES-128-ECB | `interfacepc.music.163.com/eapi/*` |
| linuxapi | AES-128-ECB | `music.163.com/api/linux/forward` |
| api | 明文 | `interface.music.163.com/api/*` |

加密实现有单元测试，测试向量用 OpenSSL / Python 独立算出。

- **会话**：`Session` 保存全部 cookie。首次创建时生成一套固定的设备指纹（`deviceId`、`_ntes_nuid`、`NMTID` 等），随会话一起持久化，避免每次请求都像一台新设备。
- **海外网络**：网易云会对海外出口 IP 返回 `code 404 / cannotListenReason 1`。`Session::real_ip` 设置后会带上 `X-Real-IP` / `X-Forwarded-For`。默认 IP 从实测可用的国内网段里随机选取，见 `ncm-core` 的 `CN_PREFIXES`。
- **数据模型**：网易云字段时而整数、时而浮点、时而为 `null`，模型统一用宽松的反序列化（`num` / `nn`）。
- **TLS**：reqwest 使用 rustls + ring，不依赖系统 OpenSSL，交叉编译到安卓更省事。

尚未实现 xeapi / neapi 通道。api-enhanced 已把部分接口切到 xeapi，目前对应接口用 eapi 仍然可用，以后需要时再补。

## ncm-player：音频引擎

```
下载线程 ──写入──▶ 缓存文件(.part) ◀──读取── StreamingSource ──▶ symphonia 解码
                                                                     │ f32 交错样本
引擎线程（命令 / 解码 / 跳转）──────────▶ rtrb 环形缓冲（约 0.5 秒）──▶ cpal 回调 × 音量
```

- **边下边播**：`StreamingSource` 实现了 `Read + Seek`，读到还没下载的位置就等待。下载完成后 `.part` 改名为正式缓存文件，下次播放直接读本地。
- **按音源采样率开流**：PipeWire、WASAPI、AAudio 都会在系统侧重采样，所以引擎里不做重采样。
- **精确跳转**：跳转后丢弃目标时间戳之前的样本；清空缓冲时通过 `flush_req` / `flush_ack` 两个原子量与音频回调握手，避免旧样本漏出来。
- **进度**：音频回调统计实际播出的帧数，加上跳转基准就是当前位置，不受缓冲延迟影响。
- **音量**：滑块值按平方曲线映射，听感更线性。

## ncm-core：业务核心

- `Core` 持有 `Client`、`Player`、`Queue` 与设置，通过 `tokio::sync::broadcast` 对外发 `CoreEvent`。
- 曲目自然结束时，按播放模式自动切到下一首；连续失败（无版权等）最多跳过 5 首，避免整张歌单都放不了时死循环。
- 数据目录（Linux）：`~/.local/share/yeteasemusic/`，其中 `session.json`（0600）保存登录 cookie，`settings.json` 保存设置。音频缓存在 `~/.cache/yeteasemusic/audio/`。

## FFI 层（app/rust）

- 自建 tokio 运行时（`state::rt()`）。frb 的执行器不保证是 tokio，而内核依赖 tokio。
- **Dart 只传歌曲 id**：所有列表接口返回的歌曲都缓存在 Rust 侧（`state::remember`），播放时按 id 查找，缺的再批量拉详情，避免整首歌的数据在两种语言之间来回复制。
- 播放状态通过 `events()` 流推送给 Dart，由 Rust 主动推，而不是 Dart 定时轮询；需要全量状态时调 `snapshot()`。

## 界面层（app/lib）

- `state.dart`：把 Rust 事件转成 `ValueNotifier`，界面各处按需监听。
- `theme.dart`：颜色、圆角、尺寸都集中在这里（`Tokens` + `Palette`），页面里不写魔法数。
- `ui/nav.dart`：内容区的嵌套 Navigator。侧边栏切换清空栈，页面内跳转压栈。
- `ui/ui_scaled.dart`：整体界面缩放，同步调整 `devicePixelRatio`，图片按真实像素解码。
- **Impeller 注意事项**：Linux 上 Flutter 走 Impeller 的 OpenGLES 后端，"圆形 + 渐变 / 阴影"装饰会退化成方块，旋转时还会出伪影。所以圆形元素一律用 `ClipOval` 裁剪，不要依赖 `BoxShape.circle` 配合 `gradient` 或 `boxShadow`。
