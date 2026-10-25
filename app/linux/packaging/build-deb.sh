#!/usr/bin/env bash
# 打 .deb 包：桌面版 + 命令行版。
#   用法：build-deb.sh <版本号> <Flutter bundle 目录> <命令行二进制> <输出目录>
# 安装位置：
#   /opt/yetease-music/                 程序
#   /usr/bin/yetease-music -> 上面      桌面版
#   /usr/bin/yetease                    命令行版
#   /usr/share/applications/…desktop    启动项（中文系统显示「网易云音乐Yet」）
#   /usr/share/icons/hicolor/…          图标
set -euo pipefail
VERSION="$1"
BUNDLE="$2"
CLI="$3"
OUT="$4"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP_ID=io.github.gloridust.YetEaseMusic
PKG=yetease-music
ARCH=amd64

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

install -d "$ROOT/opt/$PKG" "$ROOT/usr/bin" "$ROOT/usr/share/applications" "$ROOT/usr/share/doc/$PKG" "$ROOT/DEBIAN"
cp -a "$BUNDLE/." "$ROOT/opt/$PKG/"
ln -s "/opt/$PKG/yetease-music" "$ROOT/usr/bin/yetease-music"
install -m 0755 "$CLI" "$ROOT/usr/bin/yetease"

sed "s|^Exec=.*|Exec=/opt/$PKG/yetease-music %U|" "$HERE/$APP_ID.desktop" > "$ROOT/usr/share/applications/$APP_ID.desktop"
for f in "$HERE"/icons/*.png; do
  s="$(basename "$f" .png)"
  install -D -m 0644 "$f" "$ROOT/usr/share/icons/hicolor/${s}x${s}/apps/$APP_ID.png"
done
# 矢量图标：高分屏、任意缩放下都清晰
install -D -m 0644 "$HERE/icons/scalable.svg" "$ROOT/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"
cp "$HERE/../../../LICENSE" "$ROOT/usr/share/doc/$PKG/copyright"

SIZE_KB="$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)"
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Architecture: $ARCH
Maintainer: YetEase Music <yetease@users.noreply.github.com>
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.34), libgtk-3-0t64 | libgtk-3-0, libasound2t64 | libasound2, ca-certificates
Section: sound
Priority: optional
Homepage: https://github.com/Gloridust/YetEaseMusic
Description: Fast, clean third-party client for NetEase Cloud Music
 YetEase Music (网易云音乐Yet) is an unofficial NetEase Cloud Music client
 with a Rust core and a Flutter UI. It talks to the official API directly,
 with no third-party servers and no ads. Includes the desktop app
 (yetease-music) and the command-line / terminal UI client (yetease).
EOF

mkdir -p "$OUT"
dpkg-deb --build --root-owner-group "$ROOT" "$OUT/${PKG}_${VERSION}_${ARCH}.deb"
echo "$OUT/${PKG}_${VERSION}_${ARCH}.deb"
