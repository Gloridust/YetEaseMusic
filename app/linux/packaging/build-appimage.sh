#!/usr/bin/env bash
# 打 AppImage：单文件，下载后加执行权限即可运行，不需要安装，也不需要 Flatpak。
#   用法：build-appimage.sh <版本号> <Flutter bundle 目录> <输出目录>
# 需要 appimagetool（APPIMAGETOOL 指定路径，默认在 PATH 里找）；有 zsyncmake 时一并生成 .zsync，
# 配合内嵌的更新信息，AppImageUpdate / Gear Lever 等工具可以增量升级。
set -euo pipefail
VERSION="$1"
BUNDLE="$2"
OUT="$3"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP_ID=io.github.gloridust.YetEaseMusic
TOOL="${APPIMAGETOOL:-appimagetool}"
NAME="yetease-music-$VERSION-x86_64.AppImage"

APPDIR="$(mktemp -d)/YetEase.AppDir"
trap 'rm -rf "$(dirname "$APPDIR")"' EXIT

install -d "$APPDIR/usr/lib/yetease-music" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/metainfo"
cp -a "$BUNDLE/." "$APPDIR/usr/lib/yetease-music/"

# 程序通过 /proc/self/exe 找自己的 lib 和 data，直接 exec 真实路径即可
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/lib/yetease-music/yetease-music" "$@"
EOF
chmod 755 "$APPDIR/AppRun"

sed "s|^Exec=.*|Exec=yetease-music %U|" "$HERE/$APP_ID.desktop" > "$APPDIR/$APP_ID.desktop"
cp "$APPDIR/$APP_ID.desktop" "$APPDIR/usr/share/applications/"
cp "$HERE/$APP_ID.metainfo.xml" "$APPDIR/usr/share/metainfo/$APP_ID.appdata.xml"
cp "$HERE/icons/256.png" "$APPDIR/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"
for f in "$HERE"/icons/*.png; do
  s="$(basename "$f" .png)"
  install -Dm644 "$f" "$APPDIR/usr/share/icons/hicolor/${s}x${s}/apps/$APP_ID.png"
done

mkdir -p "$OUT"
# metainfo 里的截图要联网校验，打包时跳过（Flathub 构建时会校验）
ARCH=x86_64 "$TOOL" --no-appstream \
  -u "gh-releases-zsync|Gloridust|YetEaseMusic|latest|yetease-music-*-x86_64.AppImage.zsync" \
  "$APPDIR" "$OUT/$NAME"
# appimagetool 把 .zsync 写在当前目录
if [ -f "$NAME.zsync" ]; then mv "$NAME.zsync" "$OUT/"; fi
echo "$OUT/$NAME"
