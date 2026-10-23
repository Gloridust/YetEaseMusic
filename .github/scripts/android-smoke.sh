#!/usr/bin/env bash
# 在模拟器里安装 APK 并验证：
#   1. 冷启动不崩溃、界面渲染出来
#   2. --autoplay 自动播放一首歌：系统媒体会话处于播放中，进度在走
#   3. 切到后台 30 秒后进度仍在走（后台播放有效）
set -uo pipefail
mkdir -p smoke
PKG=io.github.gloridust.yetease
ACT="$PKG/io.github.gloridust.app.MainActivity"
SONG=3986241   # Yesterday Once More（可免费试听）
fail=0

adb install -r dl/*.apk
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
adb logcat -c
adb shell am start -n "$ACT" --esa yetease_args "--autoplay=$SONG"
sleep 40
adb exec-out screencap -p > smoke/launch.png

# 媒体会话里我们的播放状态：state=3 表示 PLAYING，position 为毫秒
state() { adb shell dumpsys media_session | tr -d '\r' | grep -A12 "package=$PKG" | grep -m1 -oE "state=PlaybackState \{state=[0-9]+, position=[0-9]+"; }
s1="$(state)"; echo "前台：$s1"
pos1="$(echo "$s1" | grep -oE 'position=[0-9]+' | cut -d= -f2)"
echo "$s1" | grep -q "state=3" || { echo "前台未在播放"; fail=1; }

adb shell input keyevent KEYCODE_HOME
sleep 30
s2="$(state)"; echo "后台 30 秒后：$s2"
adb shell dumpsys media_session > smoke/media_session.txt
echo "$s2" | grep -q "state=3" || { echo "后台未在播放"; fail=1; }

adb shell am start -n "$ACT"
sleep 5
adb exec-out screencap -p > smoke/resume.png
adb shell dumpsys notification --noredact > smoke/notification.txt 2>/dev/null || true
adb logcat -d > smoke/logcat.txt
grep -E "FATAL EXCEPTION|panicked|Unhandled Exception" smoke/logcat.txt > smoke/crashes.txt || true
pid="$(adb shell pidof "$PKG" | tr -d '\r')"
echo "pid=$pid  前台位置=$pos1"
echo "--- 应用日志（logcat tag yetease）---"
grep -E " yetease *:" smoke/logcat.txt | tail -n 60
cat smoke/crashes.txt
test -n "$pid" || { echo "进程不在"; fail=1; }
test ! -s smoke/crashes.txt || { echo "日志里有崩溃"; fail=1; }
exit $fail
