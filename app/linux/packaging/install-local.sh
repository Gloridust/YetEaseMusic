#!/usr/bin/env bash
# 把 release 构建装到当前用户目录（不需要 root）：
#   程序     ~/.local/opt/yetease-music/
#   命令     ~/.local/bin/yetease-music
#   启动项   ~/.local/share/applications/io.github.gloridust.YetEaseMusic.desktop
#   图标     ~/.local/share/icons/hicolor/<size>/apps/io.github.gloridust.YetEaseMusic.png
# 卸载：加 --uninstall
set -euo pipefail
APP_ID=io.github.gloridust.YetEaseMusic
# 0.2.4 之前用的应用 ID，安装和卸载时顺手清掉，避免菜单里出现两个
OLD_ID=io.github.gloridust.yetease
HERE="$(cd "$(dirname "$0")" && pwd)"
# 发布包里程序就在同目录的 bundle/；在源码树里则取构建产物
if [[ -x "$HERE/bundle/yetease-music" ]]; then
  BUNDLE="$HERE/bundle"
else
  BUNDLE="$HERE/../../build/linux/x64/release/bundle"
fi
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"
OPT="$HOME/.local/opt/yetease-music"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -rf "$OPT" "$HOME/.local/bin/yetease-music" "$PREFIX/applications/$APP_ID.desktop" "$PREFIX/applications/$OLD_ID.desktop"
  find "$PREFIX/icons/hicolor" \( -name "$APP_ID.png" -o -name "$APP_ID.svg" -o -name "$OLD_ID.png" \) -delete 2>/dev/null || true
  # 用户目录的 hicolor 没有 index.theme，不加 -t 会静默失败，缓存里留着已删的图标，桌面就显示空白图标
  gtk-update-icon-cache -q -t -f "$PREFIX/icons/hicolor" 2>/dev/null || true
  update-desktop-database -q "$PREFIX/applications" 2>/dev/null || true
  echo "已卸载"
  exit 0
fi

[[ -x "$BUNDLE/yetease-music" ]] || { echo "先在 app/ 下运行 flutter build linux --release" >&2; exit 1; }

rm -rf "$OPT" "$PREFIX/applications/$OLD_ID.desktop"
find "$PREFIX/icons/hicolor" -name "$OLD_ID.png" -delete 2>/dev/null || true
mkdir -p "$OPT" "$HOME/.local/bin" "$PREFIX/applications"
cp -a "$BUNDLE/." "$OPT/"
ln -sf "$OPT/yetease-music" "$HOME/.local/bin/yetease-music"

for f in "$HERE"/icons/*.png; do
  s="$(basename "$f" .png)"
  mkdir -p "$PREFIX/icons/hicolor/${s}x${s}/apps"
  cp "$f" "$PREFIX/icons/hicolor/${s}x${s}/apps/$APP_ID.png"
done
mkdir -p "$PREFIX/icons/hicolor/scalable/apps"
cp "$HERE/icons/scalable.svg" "$PREFIX/icons/hicolor/scalable/apps/$APP_ID.svg"

sed "s|^Exec=.*|Exec=$OPT/yetease-music %U|" "$HERE/$APP_ID.desktop" > "$PREFIX/applications/$APP_ID.desktop"
gtk-update-icon-cache -q -t "$PREFIX/icons/hicolor" 2>/dev/null || true
update-desktop-database -q "$PREFIX/applications" 2>/dev/null || true
echo "已安装到 $OPT，可以在应用菜单里搜索「网易云音乐Yet」/「YetEase Music」"
