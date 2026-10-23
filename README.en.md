<div align="center">

<img src="doc/logo.svg" width="96" alt="YetEase Music">

# YetEase Music

**A fast, clean and good-looking third-party client for NetEase Cloud Music**

Rust native core × Flutter-rendered UI · Built for Linux first, with Windows tablets, Android head units and the terminal in mind

[中文](README.md) · [Architecture](doc/architecture.md) · [Build from source](doc/building.md)

![Linux](https://img.shields.io/badge/Linux-available-2ea44f?logo=linux&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-in%20progress-f0ad4e?logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android%20%2F%20car-in%20progress-f0ad4e?logo=android&logoColor=white)
![CLI](https://img.shields.io/badge/CLI-available-2ea44f?logo=gnometerminal&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

<img src="doc/screenshots/now-playing.webp" alt="Now playing: cover-tinted backdrop, spinning vinyl and bilingual synced lyrics">

</div>

---

## Why

NetEase has never really cared about these places:

- **Linux** – the official native client stopped at 1.2.1 in 2019 and can no longer stream;
- **Windows tablets** – only a mouse-first desktop app, awkward to use by touch;
- **Android head units** – the phone app stretched onto a wide screen, with tiny buttons and ads;
- **The terminal** – nothing at all.

YetEase fills those gaps: **one core, many front-ends, each feeling native to where it runs.**

## Highlights

### ⚡ Native speed

Decoding, caching, networking and lyric parsing all run in **Rust**. On its own, the playback core stays at about **16 MB** of resident memory. Songs play while they download and become an offline cache once finished, so replays cost no bandwidth.

### 🎨 A native look and feel

The UI is drawn by **Flutter**, following the layout and details of the official Windows and iPad apps:

- the now-playing screen derives its gradient from the album art, the record spins while playing and the tonearm lifts on pause;
- lyrics scroll line by line with translations, and clicking a line seeks to it;
- light / dark themes and adjustable UI scaling, crisp on HiDPI screens.

### 🧩 One core, every platform

Protocol, playback, queue and cache live in a shared Rust core; the UI layer only decides how things look. That means:

- the desktop app and the CLI share the **same** playback engine;
- porting to a new platform means building a UI, not rewriting the logic;
- narrow windows switch to a compact layout, ready for phone and head-unit screens.

### 🔒 Clean

- **Talks to NetEase's official API directly** – no third-party servers in between;
- **No ads**, no promotions, no telemetry;
- your login stays on your own machine.

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="doc/screenshots/home.webp" alt="Discover"></td>
    <td width="50%"><img src="doc/screenshots/playlist-dark.webp" alt="Playlist (dark)"></td>
  </tr>
  <tr>
    <td align="center">Recommended playlists</td>
    <td align="center">Playlist · dark mode</td>
  </tr>
  <tr>
    <td width="50%"><img src="doc/screenshots/search.webp" alt="Search"></td>
    <td width="50%"><img src="doc/screenshots/settings.webp" alt="Settings"></td>
  </tr>
  <tr>
    <td align="center">Search</td>
    <td align="center">Settings: quality, overseas mode, theme and scaling</td>
  </tr>
</table>

<p align="center">
  <img src="doc/screenshots/compact.webp" width="300" alt="Compact layout"><br>
  <sub>Compact layout for narrow windows</sub>
</p>

## Features

| | Status |
|---|---|
| QR-code login, account playlists | ✅ |
| Recommended playlists, daily picks | ✅ |
| Playlist details, in-playlist search, shuffle | ✅ |
| Song search with infinite scrolling | ✅ |
| Like / unlike | ✅ |
| Play queue, play next, four play modes | ✅ |
| Stream-while-downloading with auto cache, Standard to Hi-Res quality | ✅ |
| Synced lyrics with translations, click to seek | ✅ |
| Light / dark theme, UI scaling, space to play / pause | ✅ |
| Overseas mode (keeps playback working abroad or behind a global proxy) | ✅ |
| CLI: login, search, playlists, daily picks, playback | ✅ |
| System media controls (Linux MPRIS / Windows SMTC) | 🚧 |
| Album, artist and chart pages | 🚧 |
| Recently played, downloads, local music | 🚧 |
| Desktop lyrics, word-by-word lyrics | 📝 |
| Windows installer, Android / head-unit app | 🚧 |
| Terminal UI (TUI) | 📝 |

✅ done · 🚧 in progress · 📝 planned

## Platforms

| Platform | Status | Notes |
|---|---|---|
| Linux (x86_64) | ✅ available | Primary target, developed on Ubuntu 26.04 + GNOME Wayland |
| CLI | ✅ available | No GUI needed; works on servers and over SSH |
| Windows / Windows tablets | 🚧 | Core is cross-platform; UI tuning and packaging underway |
| Android / head units | 🚧 | Same, focusing on wide screens and steering-wheel keys |
| macOS | 📝 | Technically feasible, not a focus yet |

## Getting started

YetEase is in early development and has no release packages yet. Build it from source following **[doc/building.md](doc/building.md)**.

Once built, just launch the desktop app. The CLI looks roughly like this:

```bash
yetease login                     # QR-code login
yetease search yesterday          # search songs
yetease play yesterday once more  # search and play the first hit
yetease daily --play              # play today's picks
```

## FAQ

**Nothing plays when I'm abroad or behind a global proxy?**
NetEase rejects overseas IPs for licensing reasons. Turn on *Settings → Network → Overseas mode* (on by default).

**Can I play greyed-out (unlicensed) songs?**
No. YetEase only uses audio served by NetEase itself and bundles no third-party sources.

**What about VIP songs?**
Log in with a VIP account to play them according to its entitlements; otherwise only previews are available.

## Acknowledgements

- [NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/NeteaseCloudMusicApiEnhanced/api-enhanced) – the de-facto protocol reference and this project's main source of truth;
- [Binaryify/NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) – where it all started;
- [qier222/YesPlayMusic](https://github.com/qier222/YesPlayMusic) – proof that a third-party client can look great;
- [SPlayer-Dev/ncm-api-rs](https://github.com/SPlayer-Dev/ncm-api-rs), [two-mountains/ncmapi-rs](https://github.com/two-mountains/ncmapi-rs) – Rust references;
- [Symphonia](https://github.com/pdeljanov/Symphonia), [cpal](https://github.com/RustAudio/cpal), [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge), [Flutter](https://flutter.dev).

## Disclaimer

YetEase Music is an unofficial third-party client and is not affiliated with NetEase, Inc. or NetEase Cloud Music. It is provided for learning and personal use only. All music content belongs to NetEase Cloud Music and the respective rights holders. Please support the artists.

## License

[MIT](LICENSE)
