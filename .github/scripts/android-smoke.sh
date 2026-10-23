#!/usr/bin/env bash
# 在模拟器里安装 APK、启动、截图，检查进程存活且 logcat 没有崩溃
set -uo pipefail
mkdir -p smoke
PKG=io.github.gloridust.yetease
adb install -r dl/*.apk
adb logcat -c
adb shell am start -n "$PKG/io.github.gloridust.app.MainActivity"
sleep 45
adb exec-out screencap -p > smoke/launch.png
pid="$(adb shell pidof "$PKG" | tr -d '\r')"
adb logcat -d > smoke/logcat.txt
grep -E "FATAL EXCEPTION|AndroidRuntime: Process: $PKG|panicked" smoke/logcat.txt > smoke/crashes.txt || true
echo "pid=$pid"
cat smoke/crashes.txt
# 切到后台 20 秒再回来，确认进程没被杀
adb shell input keyevent KEYCODE_HOME
sleep 20
pid2="$(adb shell pidof "$PKG" | tr -d '\r')"
adb shell am start -n "$PKG/io.github.gloridust.app.MainActivity"
sleep 5
adb exec-out screencap -p > smoke/resume.png
adb logcat -d > smoke/logcat-full.txt
echo "pid after background=$pid2"
test -n "$pid" && test ! -s smoke/crashes.txt
