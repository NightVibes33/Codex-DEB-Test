#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== POST-CIRCLEAPPS RESPRING VERIFICATION ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null

echo
echo '=== CIRCLEAPPS FILE STATE ==='
ls -la /var/jb/usr/lib/TweakInject/CircleApps* /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleApps* 2>/dev/null || true
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' com.sugiuta.circleapps15 2>/dev/null || true

echo
echo '=== SPRINGBOARD STABILITY WINDOW ==='
P1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pid_t0=$P1"
ps ax 2>/dev/null | grep '[S]pringBoard' || true
sleep 20
P2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pid_t20=$P2"
ps ax 2>/dev/null | grep '[S]pringBoard' || true

echo
echo '=== SPRINGBOARD CRASHES MODIFIED LAST 10 MINUTES ==='
find /var/mobile/Library/Logs/CrashReporter -maxdepth 5 -type f -name 'SpringBoard-*.ips' -mmin -10 -print 2>/dev/null | while IFS= read -r f; do
  stat -f '%m %Sm %N' -t '%Y-%m-%d %H:%M:%S %z' "$f" 2>/dev/null || echo "$f"
done | sort -n || true

echo
echo '=== NEWEST SPRINGBOARD CRASH FILES ==='
find /var/mobile/Library/Logs/CrashReporter -maxdepth 5 -type f -name 'SpringBoard-*.ips' -print 2>/dev/null \
 | while IFS= read -r f; do printf '%s\t%s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done \
 | sort -nr | head -n 12 || true

echo
echo '=== RESULT ==='
if [ -n "$P1" ] && [ "$P1" = "$P2" ]; then
  echo 'springboard_stable_20s=yes'
else
  echo 'springboard_stable_20s=no'
fi
echo 'POST_CIRCLEAPPS_VERIFY_COMPLETE=1'
exit 0
