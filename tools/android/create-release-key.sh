#!/usr/bin/env bash
# 生成安卓发布签名密钥，并存进 GitHub 仓库的 Actions Secret，之后 CI 发布的 APK 都用它签名。
#
# 签名必须每个版本都一样，用户才能直接覆盖安装新版本（应用内更新也依赖这一点）。
# 这个密钥一旦用于发布就不能换，丢了就只能让所有用户卸载重装，所以：
#   - 请自己运行本脚本，密钥只在你的电脑上生成
#   - 生成的 yetease-release.jks 和密码务必离线备份（密码管理器 / 加密 U 盘）
#
# 用法：tools/android/create-release-key.sh [输出目录，默认 ~/.yetease-release-key]
# 依赖：keytool（JDK 自带）、gh（已登录且对仓库有管理权限）
set -euo pipefail
REPO=Gloridust/YetEaseMusic
OUT="${1:-$HOME/.yetease-release-key}"
KS="$OUT/yetease-release.jks"

command -v keytool >/dev/null || { echo "找不到 keytool，请先安装 JDK" >&2; exit 1; }
command -v gh >/dev/null || { echo "找不到 gh，请先安装并 gh auth login" >&2; exit 1; }
[[ -e "$KS" ]] && { echo "$KS 已存在，为避免覆盖已发布的密钥，脚本停止" >&2; exit 1; }

mkdir -p "$OUT" && chmod 700 "$OUT"
read -rsp "设置密钥库密码（至少 6 位）：" PASS; echo
read -rsp "再输入一次：" PASS2; echo
[[ "$PASS" == "$PASS2" && ${#PASS} -ge 6 ]] || { echo "两次输入不一致或太短" >&2; exit 1; }

keytool -genkeypair -v -keystore "$KS" -storetype PKCS12 -alias yetease \
  -keyalg RSA -keysize 4096 -validity 36500 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=YetEase Music, O=YetEase, C=CN"
chmod 600 "$KS"

base64 -w0 "$KS" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$REPO"
printf %s "$PASS" | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO"

echo
echo "已生成 $KS，并写入仓库 Secret：ANDROID_KEYSTORE_BASE64、ANDROID_KEYSTORE_PASSWORD"
echo "证书指纹（SHA-256）："
keytool -list -v -keystore "$KS" -storepass "$PASS" | grep -m1 "SHA256"
echo
echo "请立刻把 $KS 和密码离线备份。"
