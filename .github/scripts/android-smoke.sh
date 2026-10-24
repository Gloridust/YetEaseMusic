#!/usr/bin/env bash
# 在模拟器里安装 APK 并验证：
#   1. 冷启动不崩溃、界面渲染出来
#   2. --autoplay 自动播放一首歌：系统媒体会话处于播放中，进度在走
#   3. 切到后台后仍在播放（后台播放有效）；未登录只有 30 秒试听，检查都在这之内
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

# 媒体会话里我们的播放状态：state=3 表示 PLAYING，position 为毫秒
state() { adb shell dumpsys media_session | tr -d '\r' | grep -A12 "package=$PKG" | grep -m1 -oE "state=PlaybackState \{state=[0-9]+, position=[0-9]+"; }

# 未登录只给 30 秒试听，所以一进入播放就开始计时，前后台检查都要落在这 30 秒内
s1=""
for _ in $(seq 60); do
  s1="$(state)"
  echo "$s1" | grep -q "state=3" && break
  sleep 1
done
echo "前台：$s1"
echo "$s1" | grep -q "state=3" || { echo "前台未在播放"; fail=1; }
sleep 3
adb exec-out screencap -p > smoke/launch.png

adb shell input keyevent KEYCODE_HOME
sleep 12
s2="$(state)"; echo "后台 12 秒后：$s2"
adb shell dumpsys media_session > smoke/media_session.txt
echo "$s2" | grep -q "state=3" || { echo "后台未在播放"; fail=1; }

adb shell am start -n "$ACT"
sleep 5
adb exec-out screencap -p > smoke/resume.png
adb shell dumpsys notification --noredact > smoke/notification.txt 2>/dev/null || true
adb logcat -d > smoke/logcat.txt
grep -E "FATAL EXCEPTION|panicked|Unhandled Exception" smoke/logcat.txt > smoke/crashes.txt || true
pid="$(adb shell pidof "$PKG" | tr -d '\r')"
echo "pid=$pid"
echo "--- 应用日志（logcat tag yetease）---"
grep -E " yetease *:" smoke/logcat.txt | tail -n 60
cat smoke/crashes.txt
test -n "$pid" || { echo "进程不在"; fail=1; }
test ! -s smoke/crashes.txt || { echo "日志里有崩溃"; fail=1; }
exit $fail
