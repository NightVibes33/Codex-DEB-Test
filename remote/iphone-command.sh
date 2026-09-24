#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

NAME=CircleAppsiPhone
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="/var/mobile/Media/SafeModeIsolation-$STAMP"
mkdir -p "$BACKUP"

echo '=== CONFIRMED CULPRIT ISOLATION: CircleAppsiPhone ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null
echo "backup=$BACKUP"

echo
echo '=== PACKAGE OWNER SEARCH ==='
for root in /var/jb/Library/dpkg/info /var/jb/var/lib/dpkg/info /Library/dpkg/info /var/lib/dpkg/info; do
  [ -d "$root" ] || continue
  grep -il "$NAME" "$root"/*.list 2>/dev/null | head -n 20 || true
done
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null | grep -Ei 'circleapps|circle.?apps' || true

echo
echo '=== PRE-STATE ==='
PRE_PID="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pre_springboard_pid=$PRE_PID"
ps ax 2>/dev/null | grep '[S]pringBoard' || true
find /var/mobile/Library/Logs/CrashReporter -maxdepth 5 -type f -name 'SpringBoard-*.ips' -print 2>/dev/null | sort | tail -n 12 || true

echo
echo '=== BACKUP + DISABLE ==='
disabled=0
for base in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  for ext in dylib plist; do
    f="$base/$NAME.$ext"
    [ -e "$f" ] || continue
    echo "FOUND=$f"
    cp -p "$f" "$BACKUP/$NAME.$ext" 2>/dev/null || true
    mv "$f" "$f.disabled" 2>/dev/null && {
      echo "DISABLED=$f.disabled"
      disabled=1
    }
  done
done
echo "disabled_any=$disabled"
ls -la "$BACKUP" 2>/dev/null || true
ls -la /var/jb/usr/lib/TweakInject/$NAME* /var/jb/Library/MobileSubstrate/DynamicLibraries/$NAME* 2>/dev/null || true

echo
echo '=== RESTART SPRINGBOARD ==='
if command -v sbreload >/dev/null 2>&1; then
  echo 'restart_method=sbreload'
  sbreload 2>&1 || true
else
  echo 'restart_method=killall'
  killall -9 SpringBoard 2>&1 || true
fi

sleep 12
PID1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pid_after_12s=$PID1"
ps ax 2>/dev/null | grep '[S]pringBoard' || true
sleep 15
PID2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pid_after_27s=$PID2"
ps ax 2>/dev/null | grep '[S]pringBoard' || true

echo
echo '=== NEW SPRINGBOARD CRASHES AFTER ISOLATION ==='
find /var/mobile/Library/Logs/CrashReporter -maxdepth 5 -type f -name 'SpringBoard-*.ips' -mmin -3 -print 2>/dev/null | sort || true

echo
echo '=== ISOLATION RESULT ==='
result=unknown
if [ "$disabled" = 1 ] && [ -n "$PID1" ] && [ "$PID1" = "$PID2" ]; then
  recent="$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 5 -type f -name 'SpringBoard-*.ips' -mmin -1 -print 2>/dev/null | wc -l | tr -d ' ')"
  echo "recent_crash_count=$recent"
  if [ "$recent" = 0 ]; then
    result=stable_no_new_crash
  else
    result=stable_but_new_crash_report
  fi
fi
echo "isolation_result=$result"
echo 'CIRCLEAPPSIPHONE_ISOLATION_COMPLETE=1'
exit 0
