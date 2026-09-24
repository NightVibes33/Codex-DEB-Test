#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH

echo '=== FAST POST-CIRCLEAPPS VERIFY ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
echo '--- CircleApps state ---'
ls -la /var/jb/usr/lib/TweakInject/CircleAppsiPhone* 2>/dev/null || true
ls -la /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone* 2>/dev/null || true

echo '--- crash snapshot before ---'
ls -lt /var/mobile/Library/Logs/CrashReporter/SpringBoard-*.ips 2>/dev/null | head -n 6 || true
ls -lt /var/mobile/Library/Logs/CrashReporter/Retired/SpringBoard-*.ips 2>/dev/null | head -n 8 || true

P1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pid_t0=$P1"
ps ax 2>/dev/null | grep '[S]pringBoard' || true
sleep 15
P2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pid_t15=$P2"
ps ax 2>/dev/null | grep '[S]pringBoard' || true

echo '--- crash snapshot after ---'
ls -lt /var/mobile/Library/Logs/CrashReporter/SpringBoard-*.ips 2>/dev/null | head -n 6 || true
ls -lt /var/mobile/Library/Logs/CrashReporter/Retired/SpringBoard-*.ips 2>/dev/null | head -n 8 || true

if [ -n "$P1" ] && [ "$P1" = "$P2" ]; then
  echo 'springboard_stable_15s=yes'
else
  echo 'springboard_stable_15s=no'
fi
echo 'FAST_POST_CIRCLEAPPS_VERIFY_COMPLETE=1'
exit 0
