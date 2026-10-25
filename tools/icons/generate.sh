#!/usr/bin/env bash
# 由一份矢量设计生成各平台的应用图标。改图标只改这里，然后重新运行：
#   tools/icons/generate.sh
# 需要 rsvg-convert（librsvg2-bin）与 ImageMagick；生成结果直接提交，构建时不需要这些工具。
#
# 设计：扁平纯色品牌红圆角方形 + 白色线条，不加渐变和阴影。
# 图形是一只蜗牛：外圈螺旋是壳，从壳里伸出的两根触须分叉成「Y」，呼应 YetEase 的 Y；
# 整体仍保留音符的轮廓（壳内圆圈是符头，竖线是符干）。
# - Linux / Windows / README：圆角方形四周留 6% 边距，与系统里其他应用图标大小协调
# - macOS：按 Apple 的图标网格（1024 画布里 824 的主体）
# - Android：自适应图标（纯色背景 + 矢量前景），由启动器决定外形
# - 24–32px 线条加粗；16px 再省掉壳里的小圆圈和触须圆点，只留外壳与 Y，避免糊成一团
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RED="#EC4141"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 蜗牛线条（坐标系 0–100）。居中时以 (49, 51.5) 为中心：视觉重心在下方的壳上，按外框居中会显得偏右下
glyph() { # $1 = 线宽，$2 = tiny 时为 16px 简化版
  local dot
  dot=$(awk "BEGIN{print $1 * 0.667}")   # 触须末端的圆点比线条略粗
  if [ "${2:-}" = tiny ]; then
    cat <<EOF
  <g fill="none" stroke="#fff" stroke-width="$1" stroke-linecap="round" stroke-linejoin="round">
    <path d="M70.12 39.51 A27 27 0 1 1 34.5 31.62"/>
    <path d="M59 66 L59 35 M59 35 C57 28 51 22 46 17 M59 35 C61 28 67 22 72 17"/>
  </g>
EOF
    return
  fi
  cat <<EOF
  <g fill="none" stroke="#fff" stroke-width="$1" stroke-linecap="round" stroke-linejoin="round">
    <!-- 壳：右上方留出缺口，触须从缺口伸出 -->
    <path d="M70.12 39.51 A27 27 0 1 1 34.5 31.62"/>
    <circle cx="48.5" cy="57" r="10.5"/>
    <!-- 颈部向上，在顶端分叉成 Y 字形的两根触须 -->
    <path d="M59 57 L59 35 M59 35 C57 28 51 22 46 17 M59 35 C61 28 67 22 72 17"/>
  </g>
  <g fill="#fff"><circle cx="46" cy="17" r="$dot"/><circle cx="72" cy="17" r="$dot"/></g>
EOF
}

# 圆角方形图标。$1 主体左上角（0–100），$2 主体边长，$3 圆角半径，$4 图形缩放，$5 线宽，$6 可选 tiny
icon_svg() {
  local x=$1 w=$2 r=$3 k=$4 sw=$5 mode=${6:-}
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 100 100">
  <rect x="$x" y="$x" width="$w" height="$w" rx="$r" fill="$RED"/>
  <g transform="translate(50 50) scale($k) translate(-49 -51.5)">
$(glyph "$sw" "$mode")
  </g>
</svg>
EOF
}

render() { # $1 svg, $2 尺寸, $3 输出
  rsvg-convert -w "$2" -h "$2" "$1" -o "$3"
}

# ---------- 通用（Linux / Windows / README） ----------
icon_svg 6 88 18 0.96 7.2 > "$TMP/icon.svg"
icon_svg 6 88 18 0.96 9.5 > "$TMP/icon-small.svg"   # 24–32px 用粗线
icon_svg 6 88 18 0.96 11 tiny > "$TMP/icon-tiny.svg"  # 16px 简化版

LINUX="$ROOT/app/linux/packaging/icons"
mkdir -p "$LINUX"
pick() { # 按尺寸选源图：$1 尺寸，$2 前缀（icon / mac）
  if [ "$1" -le 16 ]; then echo "$TMP/$2-tiny.svg"
  elif [ "$1" -le 32 ]; then echo "$TMP/$2-small.svg"
  else echo "$TMP/$2.svg"; fi
}
for s in 16 24 32 48 64 128 256 512; do
  src=$(pick "$s" icon)
  render "$src" "$s" "$LINUX/$s.png"
done
# 矢量图标：高分屏、任意缩放下都清晰
cp "$TMP/icon.svg" "$LINUX/scalable.svg"

cp "$TMP/icon.svg" "$ROOT/doc/logo.svg"
render "$TMP/icon.svg" 1024 "$ROOT/doc/logo.png"

# Windows：多尺寸 .ico
for s in 16 24 32 48 64 128 256; do
  src=$(pick "$s" icon)
  render "$src" "$s" "$TMP/win-$s.png"
done
convert "$TMP"/win-{16,24,32,48,64,128,256}.png "$ROOT/app/windows/runner/resources/app_icon.ico"

# ---------- macOS（Apple 图标网格：主体 824/1024，圆角约 22%） ----------
icon_svg 9.77 80.47 18 0.87 7.2 > "$TMP/mac.svg"
icon_svg 9.77 80.47 18 0.87 9.5 > "$TMP/mac-small.svg"
icon_svg 9.77 80.47 18 0.87 11 tiny > "$TMP/mac-tiny.svg"
MAC="$ROOT/app/macos/Runner/Assets.xcassets/AppIcon.appiconset"
for s in 16 32 64 128 256 512 1024; do
  src=$(pick "$s" mac)
  render "$src" "$s" "$MAC/app_icon_$s.png"
done

# ---------- Android 旧式图标（自适应图标见 mipmap-anydpi-v26，这里是兜底位图） ----------
RES="$ROOT/app/android/app/src/main/res"
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  render "$TMP/icon.svg" "${d#*:}" "$RES/mipmap-${d%%:*}/ic_launcher.png"
done

echo "icons generated"
