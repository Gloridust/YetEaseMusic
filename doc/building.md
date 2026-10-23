# 从源码构建

## 依赖

| 工具 | 版本（开发环境实测） |
|---|---|
| Rust | 1.99（edition 2024） |
| Flutter | 3.47 stable（Dart 3.13） |
| flutter_rust_bridge_codegen | 2.13.0（只在改了 `app/rust/src/api` 时需要） |

Linux 还需要以下系统库（Ubuntu / Debian）：

```bash
sudo apt install build-essential clang cmake ninja-build pkg-config libgtk-3-dev libasound2-dev
```

## 命令行版

```bash
cargo build --release -p ncm-cli
./target/release/yetease --help
```

## 桌面版（Linux）

```bash
cd app
flutter pub get
flutter build linux --release
./build/linux/x64/release/bundle/yetease-music
```

首次构建会通过 cargokit 编译 Rust 动态库，需要几分钟。

> 如果环境变量里有 `NODE_ENV=production` 之类会影响依赖安装的设置，请先 `unset`。
>
> 在国内可以用镜像：`FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter`、`PUB_HOSTED_URL=https://mirrors.cloud.tencent.com/dart-pub`。

## 修改 FFI 接口后

`app/rust/src/api/` 下的改动需要重新生成 Dart 绑定：

```bash
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked   # 首次
cd app && flutter_rust_bridge_codegen generate
```

生成的文件在 `app/lib/src/rust/` 和 `app/rust/src/frb_generated.rs`，不要手改。

## 测试

```bash
cargo test --workspace          # 加密测试向量、歌词解析、播放队列等
cargo run -p ncm-api --example smoke   # 联网冒烟测试（不需要登录）
cd app && flutter analyze
```

## 界面截图巡览

设置环境变量后，应用会自动走一遍主要页面并截图，用于界面回归检查和生成 README 配图：

```bash
YETEASE_DATA_DIR=/tmp/yetease-clean \
YETEASE_TOUR=/tmp/yetease-shots \
YETEASE_TOUR_DPR=1.5 \
YETEASE_TOUR_SONG="Yesterday Once More Carpenters" \
  ./build/linux/x64/release/bundle/yetease-music
```

- `YETEASE_DATA_DIR`：使用独立的数据目录，得到一个干净的未登录环境，截图里不会出现个人账号；
- `YETEASE_TOUR`：截图输出目录；
- `YETEASE_TOUR_DPR`：截图的像素倍率；
- `YETEASE_TOUR_SONG`：巡览中播放的歌（搜索关键词）。

巡览会真实播放一首歌（音量会临时调到很低）。README 里的截图转成了 webp：

```bash
for f in /tmp/yetease-shots/*.png; do
  ffmpeg -y -loglevel error -i "$f" -c:v libwebp -quality 88 "doc/screenshots/$(basename "${f%.png}").webp"
done
```
