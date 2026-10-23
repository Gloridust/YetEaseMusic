<div align="center">

<img src="doc/logo.svg" width="96" alt="YetEase Music">

# YetEase Music

**一个快、干净、好看的网易云音乐第三方客户端**

Rust 原生内核 × Flutter 自绘界面 · 为 Linux 而生，也照顾 Windows 平板、安卓车机与命令行

[English](README.en.md) · [技术文档](doc/architecture.md) · [从源码构建](doc/building.md)

![Linux](https://img.shields.io/badge/Linux-可用-2ea44f?logo=linux&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-开发中-f0ad4e?logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android%20%2F%20车机-开发中-f0ad4e?logo=android&logoColor=white)
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
| 扫码登录、账号歌单同步 | ✅ |
| 推荐歌单、每日推荐 | ✅ |
| 歌单详情、歌单内搜索、随机播放 | ✅ |
| 单曲搜索（滚动加载） | ✅ |
| 红心喜欢 / 取消喜欢 | ✅ |
| 播放队列、下一首播放、四种播放模式 | ✅ |
| 边下边播 + 自动缓存，标准到 Hi-Res 多档音质 | ✅ |
| 逐行歌词（含翻译），点击歌词跳转 | ✅ |
| 浅色 / 深色主题、界面缩放、空格键播放暂停 | ✅ |
| 海外网络模式（在海外或开全局代理时也能播放） | ✅ |
| 命令行版：登录、搜索、歌单、每日推荐、播放 | ✅ |
| 系统媒体控制（Linux MPRIS / Windows SMTC） | 🚧 |
| 专辑页、歌手页、排行榜 | 🚧 |
| 最近播放、下载管理、本地音乐 | 🚧 |
| 桌面歌词、逐字歌词 | 📝 |
| Windows 安装包、Android / 车机版 | 🚧 |
| 终端界面（TUI） | 📝 |

✅ 已完成 · 🚧 开发中 · 📝 计划中

## 平台

| 平台 | 状态 | 说明 |
|---|---|---|
| Linux（x86_64） | ✅ 可用 | 主力平台，在 Ubuntu 26.04 + GNOME Wayland 上开发测试 |
| 命令行 | ✅ 可用 | 不依赖图形界面，服务器、SSH 上都能用 |
| Windows / Windows 平板 | 🚧 | 内核已跨平台，界面适配与打包进行中 |
| Android / 安卓车机 | 🚧 | 同上，重点做横屏大屏和方向盘按键 |
| macOS | 📝 | 技术上可行，暂未投入 |

## 开始使用

目前还在早期开发阶段，暂未发布安装包，需要从源码构建，步骤见 **[doc/building.md](doc/building.md)**。

构建好之后，桌面版直接打开即可；命令行版的用法大致是：

```bash
yetease login                 # 扫码登录
yetease search 晴天            # 搜索
yetease play 晴天 周杰伦        # 搜索并播放第一首
yetease daily --play          # 播放每日推荐
```

## 常见问题

**在海外，或者开了全局代理，歌曲都放不出来？**
网易云会以版权地区为由拒绝海外 IP。打开 *设置 → 网络 → 海外网络模式*（默认开启）即可。

**灰色 / 无版权的歌能听吗？**
不能。YetEase 只使用网易云官方提供的音源，不内置任何第三方音源。

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
