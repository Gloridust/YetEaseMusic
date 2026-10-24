<div align="center">

<img src="doc/logo.svg" width="96" alt="YetEase Music">

# YetEase Music

**一个快、干净、好看的网易云音乐第三方客户端**

Rust 原生内核 × Flutter 自绘界面 · 为 Linux 而生，也照顾 Windows 平板、安卓车机与命令行

[English](README.en.md) · [技术文档](doc/architecture.md) · [从源码构建](doc/building.md)

![Linux](https://img.shields.io/badge/Linux-可用-2ea44f?logo=linux&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-可用-2ea44f?logo=windows&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-可用-2ea44f?logo=apple&logoColor=white)
![Android](https://img.shields.io/badge/Android%20%2F%20车机-测试版-f0ad4e?logo=android&logoColor=white)
![CLI](https://img.shields.io/badge/命令行-可用-2ea44f?logo=gnometerminal&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

<img src="doc/screenshots/now-playing.webp" alt="播放页：封面取色背景、黑胶唱片与双语逐行歌词">

</div>

---

## 为什么做它

网易云官方从没认真照顾过这些地方：

- **Linux**：官方原生版停在 2019 年的 1.2.1，现在已经无法联网播放；
- **Windows 平板**：只有为鼠标设计的桌面版，触屏用起来别扭；
- **安卓车机**：手机版塞进横屏大屏，按钮小、广告多；
- **终端**：根本没有。

YetEase 想把这些空白补上：**一套内核，多个界面，每一端都像是为它原生打造的。**

## 亮点

### ⚡ 原生的速度

解码、缓存、网络请求、歌词解析全部跑在 **Rust** 里。播放内核单独运行时常驻内存约 **16 MB**。在线歌曲边下边播，听完就成了离线缓存，再听不费流量。

### 🎨 接近原生的质感

界面用 **Flutter** 自绘，参照官方 Windows 版与 iPad 版的布局和细节：

- 播放页从封面取色生成渐变背景，唱片随播放转动、唱臂随暂停抬起；
- 歌词逐行滚动，自带翻译，点哪句跳到哪句；
- 浅色 / 深色主题，界面缩放可调，高分屏下文字和封面都清晰。

### 🧩 一套内核，多端运行

协议、播放、队列、缓存都在共享的 Rust 内核里，界面层只负责"长什么样"。所以：

- 桌面版和命令行版用的是**同一个**播放引擎；
- 移植到新平台只需要做界面，不用重写业务；
- 窄窗口会自动切到紧凑布局，为手机和车机的竖屏、小屏做好准备。

### 🔒 干净

- **直连网易云官方接口**，不经过任何第三方服务器；
- **没有广告**，没有推广位，没有统计上报；
- 登录信息只保存在你自己的电脑上。

## 截图

<table>
  <tr>
    <td width="50%"><img src="doc/screenshots/home.webp" alt="推荐页"></td>
    <td width="50%"><img src="doc/screenshots/playlist-dark.webp" alt="歌单页（深色）"></td>
  </tr>
  <tr>
    <td align="center">推荐歌单</td>
    <td align="center">歌单详情 · 深色模式</td>
  </tr>
  <tr>
    <td width="50%"><img src="doc/screenshots/search.webp" alt="搜索结果"></td>
    <td width="50%"><img src="doc/screenshots/settings.webp" alt="设置"></td>
  </tr>
  <tr>
    <td align="center">搜索</td>
    <td align="center">设置：音质、海外网络模式、主题与缩放</td>
  </tr>
</table>

<p align="center">
  <img src="doc/screenshots/compact.webp" width="300" alt="紧凑布局"><br>
  <sub>窄窗口自动切换紧凑布局</sub>
</p>

## 功能

| | 状态 |
|---|---|
| 扫码登录，歌单、红心、每日推荐、最近播放与手机端同步 | ✅ |
| 精选 / 歌单广场 / 排行榜，播客，关注 | ✅ |
| 歌单、专辑、歌手页面，歌手名与专辑名一点即达 | ✅ |
| 搜索单曲 / 歌单 / 专辑 / 歌手（滚动加载） | ✅ |
| 红心、心动模式、新建歌单、收藏到歌单 | ✅ |
| 播放队列、下一首播放、四种播放模式 | ✅ |
| 边下边播 + 自动缓存（可设上限），标准到 Hi-Res 多档音质 | ✅ |
| 逐字歌词（卡拉 OK 式高亮）、翻译、点击跳转，相似推荐 | ✅ |
| 桌面歌词（透明悬浮、逐字填充、可锁定） | ✅ |
| 歌曲评论（精彩评论 + 最新评论） | ✅ |
| 下载管理（自动写入标签与封面）、本地音乐 | ✅ |
| 系统媒体控制：Linux MPRIS（媒体键、GNOME 顶栏）、Windows SMTC、macOS 正在播放 | ✅ |
| 浅色 / 深色主题、界面缩放、海外网络模式 | ✅ |
| 日志导出（自动脱敏），方便反馈问题 | ✅ |
| 命令行版与终端界面（`yetease tui`） | ✅ |
| 收藏专辑、关注歌手、收藏歌单¹ | ✅ |
| Android 后台播放、通知栏 / 锁屏控件、蓝牙与方向盘按键² | ✅ |

✅ 已完成

¹ 收藏歌单需要网易云的易盾人机校验，原生客户端可能被拒，被拒时会明确提示到手机 App 中操作；取消收藏不受影响。
² 已接入 Android 媒体会话，但还没在实体车机上充分测试，欢迎反馈。

## 平台

| 平台 | 状态 | 说明 |
|---|---|---|
| Linux（x86_64） | ✅ 可用 | 主力平台，提供 `.deb`、AppImage 与通用压缩包，Ubuntu 22.04 / Debian 12 / Fedora 35 及以上 |
| 命令行 / 终端界面 | ✅ 可用 | 不依赖图形界面，服务器、SSH 上都能用 |
| Windows 10 / 11（含平板） | ✅ 可用 | 安装包与免安装版，由 CI 自动构建 |
| macOS（Intel / Apple 芯片） | ✅ 可用 | 通用 dmg，由 CI 自动构建；未签名，首次打开需右键选「打开」 |
| Android / 安卓车机 | 🧪 测试版 | 支持后台播放与媒体按键；车机实机测试中 |

## 开始使用

到 **[Releases](https://github.com/Gloridust/YetEaseMusic/releases/latest)** 下载对应平台的安装包：

| 平台 | 文件 |
|---|---|
| Ubuntu / Debian | `yetease-music_<版本>_amd64.deb`，双击或 `sudo apt install ./yetease-music_*.deb` |
| 任意 Linux（免安装） | `yetease-music-<版本>-x86_64.AppImage`，下载后右键「属性 → 允许作为程序执行」，或 `chmod +x` 后双击运行 |
| 其他 Linux | `yetease-music-<版本>-linux-x86_64.tar.gz`，解压后运行 `./install.sh`，会添加到应用菜单 |
| Windows | `yetease-music-<版本>-windows-x64-setup.exe`（另有免安装版 zip） |
| macOS | `yetease-music-<版本>-macos-universal.dmg` |
| Android | `yetease-music-<版本>-android-universal.apk`（不确定架构就选它） |

想自己编译，见 **[doc/building.md](doc/building.md)**。

命令行版（deb 里自带，也可以单独下载）：

```bash
yetease login                 # 扫码登录
yetease tui                   # 全屏终端界面
yetease search 晴天            # 搜索
yetease play 晴天 周杰伦        # 搜索并播放第一首
yetease daily --play          # 播放每日推荐
```

## 常见问题

**在海外，或者开了全局代理，歌曲都放不出来？**
网易云会以版权地区为由拒绝海外 IP。打开 *设置 → 网络 → 海外网络模式*（默认开启）即可。

**灰色 / 无版权的歌能听吗？**
不能。YetEase 只使用网易云官方提供的音源，不内置任何第三方音源。

**GNOME 下桌面歌词不能置顶？**
GNOME（Wayland）不允许应用自己置顶窗口。在歌词窗口上按 Alt+Space，选「置顶」即可。X11、Windows、macOS 会自动置顶。

**遇到问题怎么反馈？**
*设置 → 反馈 → 导出日志*，把生成的文件附到 [Issue](https://github.com/Gloridust/YetEaseMusic/issues/new) 里。导出的日志已自动抹掉登录凭据。

**会员歌曲呢？**
登录有会员的账号即可按会员权益播放；未登录或非会员只能播放试听片段。

## 致谢

- [NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced)：接口协议的事实标准，也是本项目的主要参考；
- [Binaryify/NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi)：这一切的起点；
- [qier222/YesPlayMusic](https://github.com/qier222/YesPlayMusic)：好看的第三方客户端可以长什么样；
- [SPlayer-Dev/ncm-api-rs](https://github.com/SPlayer-Dev/ncm-api-rs)、[two-mountains/ncmapi-rs](https://github.com/two-mountains/ncmapi-rs)：Rust 实现的参考；
- [Symphonia](https://github.com/pdeljanov/Symphonia)、[cpal](https://github.com/RustAudio/cpal)、[flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge)、[Flutter](https://flutter.dev)。

## 声明

YetEase Music 是非官方的第三方客户端，与网易公司及网易云音乐没有任何关联。本项目仅供学习与交流，音乐内容的版权归网易云音乐及相应权利人所有。请支持正版，有条件的话开通会员支持创作者。

## 许可

[MIT](LICENSE)
