#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== POST-CIRCLEAPPS BOUNDED VERIFICATION ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null

echo
echo '=== CIRCLEAPPS INJECTION STATE ==='
for f in  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib.disabled  /var/jb/usr/lib/TweakInject/CircleAppsiPhone.plist.disabled  /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib  /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.plist  /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib.disabled  /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.plist.disabled; do
  if [ -e "$f" ]; then echo "present=$f"; else echo "absent=$f"; fi
done

echo
echo '=== SPRINGBOARD STABILITY ==='
P1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pid_t0=$P1"
ps ax 2>/dev/null | grep '[S]pringBoard' || true
sleep 15
P2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "pid_t15=$P2"
ps ax 2>/dev/null | grep '[S]pringBoard' || true

echo
echo '=== RETIRED SPRINGBOARD CRASHES ==='
RET=/var/mobile/Library/Logs/CrashReporter/Retired
if [ -d "$RET" ]; then
  ls -lt "$RET"/SpringBoard-*.ips 2>/dev/null | head -n 15 || true
fi

echo
echo '=== ACTIVE CRASHREPORTER TOP-LEVEL SPRINGBOARD ==='
CR=/var/mobile/Library/Logs/CrashReporter
if [ -d "$CR" ]; then
  ls -lt "$CR"/SpringBoard-*.ips 2>/dev/null | head -n 15 || true
fi

echo
echo '=== QUICK CIRCLEAPPS LOAD CHECK ==='
if [ -n "$P2" ] && command -v vmmap >/dev/null 2>&1; then
  vmmap "$P2" 2>/dev/null | grep -i 'CircleApps' | head -n 20 || true
else
  echo 'vmmap_unavailable_or_no_pid=1'
fi

echo
echo '=== RESULT ==='
RESULT=pass
[ -n "$P1" ] || RESULT=fail
[ "$P1" = "$P2" ] || RESULT=fail
[ ! -e /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib ] || RESULT=fail
[ ! -e /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib ] || RESULT=fail
echo "springboard_stable_15s=$([ -n "$P1" ] && [ "$P1" = "$P2" ] && echo yes || echo no)"
echo "circleappsiphone_enabled_payload_absent=$([ ! -e /var/jb/usr/lib/TweakInject/CircleAppsiPhone.dylib ] && [ ! -e /var/jb/Library/MobileSubstrate/DynamicLibraries/CircleAppsiPhone.dylib ] && echo yes || echo no)"
echo "verification_result=$RESULT"
echo 'POST_CIRCLEAPPS_BOUNDED_VERIFY_COMPLETE=1'
exit 0
