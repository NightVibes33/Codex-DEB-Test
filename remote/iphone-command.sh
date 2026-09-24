#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile
TI=/var/jb/usr/lib/TweakInject
MARKER=/var/mobile/Media/circleapps-final-fix.marker

echo '=== FAST POST-RESTART VERIFY ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true

echo
echo '=== PROCESS STATE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
SBPID="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
BBPID="$(ps ax 2>/dev/null | awk '/[b]ackboardd/{print $1; exit}')"
echo "springboard_pid=$SBPID"
echo "backboardd_pid=$BBPID"
[ -n "$SBPID" ] && ps -p "$SBPID" -o pid=,etime=,command= 2>/dev/null || true

echo
echo '=== CIRCLEAPPS ACTIVE FILES ==='
for f in CircleAppsiPhone.dylib CircleAppsiPhone.plist ZZCircleAppsCompat.dylib ZZCircleAppsCompat.plist; do
  if [ -s "$TI/$f" ]; then
    echo "ACTIVE=$f"
  else
    echo "MISSING_OR_EMPTY=$f"
  fi
done
for f in CircleAppsiPhone.dylib.disabled CircleAppsiPhone.plist.disabled; do
  [ -e "$TI/$f" ] && echo "UNEXPECTED_DISABLED=$f"
done
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n'   com.sugiuta.circleapps15 ws.hbang.common com.opa334.altlist preferenceloader ellekit 2>/dev/null || true

echo
echo '=== CIRCLEAPPS FILTERS ==='
plutil -p "$TI/CircleAppsiPhone.plist" 2>/dev/null || true
plutil -p "$TI/ZZCircleAppsCompat.plist" 2>/dev/null || true

echo
echo '=== CIRCLEAPPS PREF ==='
PREF=/var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist
if [ -f "$PREF" ]; then
  plutil -p "$PREF" 2>/dev/null || true
else
  echo 'circleapps_pref=missing'
fi

echo
echo '=== NEW SPRINGBOARD CRASH COUNT ==='
NEWCR=0
if [ -e "$MARKER" ]; then
  for root in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
    [ -d "$root" ] || continue
    for f in "$root"/SpringBoard-*.ips; do
      [ -f "$f" ] || continue
      [ "$f" -nt "$MARKER" ] || continue
      NEWCR=$((NEWCR+1))
      echo "NEW_CRASH=$f"
      grep -a -Eo 'CircleAppsiPhone[^"]*|ZZCircleAppsCompat[^"]*|NSInvalidArgumentException[^"]*|insertObject:[^"]*' "$f" 2>/dev/null | head -n 20 || true
    done
  done
else
  echo 'restart_marker=missing'
fi
echo "new_springboard_crashes=$NEWCR"

echo
echo '=== SPRINGBOARD TWEAK FILTER HEALTH ==='
EXPECTED=0
BAD=0
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  strings "$p" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard' || continue
  n="$(basename "$p" .plist)"
  EXPECTED=$((EXPECTED+1))
  if [ ! -s "$TI/$n.dylib" ]; then
    BAD=$((BAD+1))
    echo "ISSUE|missing-dylib|$n"
  elif [ ! -x "$TI/$n.dylib" ]; then
    BAD=$((BAD+1))
    echo "ISSUE|non-executable-dylib|$n"
  fi
  plutil -p "$p" >/dev/null 2>&1 || { BAD=$((BAD+1)); echo "ISSUE|bad-filter|$n"; }
done
echo "springboard_targeting_tweaks=$EXPECTED"
echo "springboard_structural_issues=$BAD"

echo
echo '=== DISABLED TWEAK FILES ==='
find "$TI" -maxdepth 1 -type f -name '*.disabled' -print 2>/dev/null | sort || true

echo
echo '=== CHOICY ==='
plutil -p /var/mobile/Library/Preferences/com.opa334.choicy.plist 2>/dev/null || true

echo
echo '=== PACKAGE AUDIT ==='
dpkg --audit 2>&1 || true

echo
echo '=== RESULT ==='
if [ -n "$SBPID" ]    && [ -s "$TI/CircleAppsiPhone.dylib" ]    && [ -s "$TI/ZZCircleAppsCompat.dylib" ]    && [ "$NEWCR" -eq 0 ]    && [ "$BAD" -eq 0 ]; then
  echo 'post_restart_verify=PASS'
else
  echo 'post_restart_verify=NEEDS_ATTENTION'
fi
echo 'FAST_POST_RESTART_VERIFY_COMPLETE=1'
exit 0
