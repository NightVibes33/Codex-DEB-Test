#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

TI=/var/jb/usr/lib/TweakInject
MARKER=/var/mobile/Media/circleapps-final-fix.marker

echo '=== POST-RESTART TWEAK VERIFICATION ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true

echo
echo '=== SPRINGBOARD / SAFE MODE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
SBPID="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
BBPID="$(ps ax 2>/dev/null | awk '/[b]ackboardd/{print $1; exit}')"
echo "springboard_pid=$SBPID"
echo "backboardd_pid=$BBPID"
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true

echo
echo '=== CIRCLEAPPS INSTALLED STATE ==='
for f in  "$TI/CircleAppsiPhone.dylib"  "$TI/CircleAppsiPhone.plist"  "$TI/ZZCircleAppsCompat.dylib"  "$TI/ZZCircleAppsCompat.plist"; do
  if [ -e "$f" ]; then
    ls -lT "$f" 2>/dev/null || ls -l "$f" 2>/dev/null || true
    [ "${f##*.}" = dylib ] && file "$f" 2>/dev/null || true
  else
    echo "MISSING=$f"
  fi
done
if [ -e "$TI/CircleAppsiPhone.dylib.disabled" ] || [ -e "$TI/CircleAppsiPhone.plist.disabled" ]; then
  echo 'circleapps_disabled_copy_present=yes'
else
  echo 'circleapps_disabled_copy_present=no'
fi
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n'   com.sugiuta.circleapps15 ws.hbang.common com.opa334.altlist preferenceloader ellekit 2>/dev/null || true

echo
echo '=== CIRCLEAPPS PREFERENCES ==='
for f in /var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist /var/mobile/Library/Preferences/*.plist; do
  [ -f "$f" ] || continue
  strings "$f" 2>/dev/null | grep -q 'selectedApplications' || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null | grep -A50 -B5 'selectedApplications' || true
done

echo
echo '=== CIRCLEAPPS GUARD LOG ==='
if command -v log >/dev/null 2>&1; then
  log show --last 15m --style compact 2>/dev/null     | grep -F 'ZZCircleAppsCompat' | tail -n 80 || true
else
  echo 'log_tool=missing'
fi

echo
echo '=== CRASHES SINCE CIRCLEAPPS RESTART MARKER ==='
NEWCR=0
if [ -e "$MARKER" ]; then
  ls -lT "$MARKER" 2>/dev/null || true
  for root in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
    [ -d "$root" ] || continue
    for f in "$root"/SpringBoard-*.ips; do
      [ -f "$f" ] || continue
      [ "$f" -nt "$MARKER" ] || continue
      NEWCR=$((NEWCR+1))
      echo "NEW_CRASH=$f"
      tr ',' '\n' < "$f" 2>/dev/null         | grep -a -Ei 'exception|signal|abort|CircleApps|ZZCircleAppsCompat|insertObject|TweakInject|faultingThread'         | cut -c 1-1800 | head -n 120 || true
    done
  done
else
  echo 'restart_marker=missing'
fi
echo "new_springboard_crashes=$NEWCR"

echo
echo '=== SPRINGBOARD-TARGETING TWEAK INVENTORY ==='
EXP=/tmp/sb-expected.$$
: > "$EXP"
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  strings "$p" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard' || continue
  n="$(basename "$p" .plist)"
  if [ -f "$TI/$n.dylib" ]; then
    echo "$n" >> "$EXP"
  else
    echo "ISSUE|filter-without-dylib|$n"
  fi
done
sort -u "$EXP" -o "$EXP"
cat "$EXP"
echo "springboard_targeting_count=$(wc -l < "$EXP" | tr -d ' ')"

echo
echo '=== DISABLED SPRINGBOARD-RELATED PAYLOADS ==='
for f in "$TI"/*.disabled; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  stem="${base%%.*}"
  sibling="$TI/$stem.plist"
  if strings "$f" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard|CircleApps'      || { [ -f "$sibling" ] && strings "$sibling" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard'; }; then
    echo "DISABLED=$f"
  fi
done

echo
echo '=== FILTER VALIDITY / FILE PERMISSIONS ==='
BAD=0
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  n="$(basename "$p" .plist)"
  if ! plutil -p "$p" >/dev/null 2>&1; then
    BAD=$((BAD+1))
    echo "ISSUE|unreadable-or-malformed-filter|$n|$p"
  fi
done
for d in "$TI"/*.dylib; do
  [ -f "$d" ] || continue
  [ -r "$d" ] || echo "ISSUE|unreadable-dylib|$d"
  [ -x "$d" ] || echo "ISSUE|non-executable-dylib|$d"
  [ -s "$d" ] || echo "ISSUE|zero-size-dylib|$d"
done
echo "bad_filter_count=$BAD"

echo
echo '=== CHOICY SPRINGBOARD RULES ==='
for f in /var/mobile/Library/Preferences/com.opa334.choicy.plist /var/mobile/Library/Preferences/com.opa334.choicyprefs.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || true
done

echo
echo '=== LIVE SPRINGBOARD TWEAK IMAGES ==='
LOADED=/tmp/sb-loaded.$$
: > "$LOADED"
if [ -n "$SBPID" ] && command -v vmmap >/dev/null 2>&1; then
  vmmap "$SBPID" 2>/dev/null     | grep -E '/(TweakInject|DynamicLibraries)/.*\.dylib'     | sed -E 's#^.*(/TweakInject/|/DynamicLibraries/)##; s#\.dylib.*$##'     | sed 's#^.*/##' | sort -u > "$LOADED" || true
  echo 'live_probe=vmmap'
elif [ -n "$SBPID" ] && command -v lsof >/dev/null 2>&1; then
  lsof -p "$SBPID" 2>/dev/null     | grep -E '/(TweakInject|DynamicLibraries)/.*\.dylib'     | sed -E 's#^.*(/TweakInject/|/DynamicLibraries/)##; s#\.dylib.*$##'     | sed 's#^.*/##' | sort -u > "$LOADED" || true
  echo 'live_probe=lsof'
else
  echo 'live_probe=unavailable'
fi
if [ -s "$LOADED" ]; then
  echo '--- LOADED ---'
  cat "$LOADED"
  echo '--- EXPECTED BUT NOT OBSERVED ---'
  while IFS= read -r n; do
    grep -Fxq "$n" "$LOADED" || echo "NOT_OBSERVED=$n"
  done < "$EXP"
fi

echo
echo '=== PACKAGE HEALTH ==='
dpkg --audit 2>&1 || true

echo
echo '=== VERDICT SIGNALS ==='
[ -f "$TI/CircleAppsiPhone.dylib" ] && echo 'circleapps_dylib_active=yes' || echo 'circleapps_dylib_active=no'
[ -f "$TI/ZZCircleAppsCompat.dylib" ] && echo 'circleapps_guard_active=yes' || echo 'circleapps_guard_active=no'
[ -z "$(launchctl getenv _MSSafeMode 2>/dev/null)" ] && echo 'substrate_safe_mode_env=clear' || echo 'substrate_safe_mode_env=set'
if [ -n "$SBPID" ] && [ "$NEWCR" -eq 0 ]; then
  echo 'post_restart_springboard_state=stable'
else
  echo 'post_restart_springboard_state=needs-attention'
fi

rm -f "$EXP" "$LOADED"
echo 'POST_RESTART_TWEAK_VERIFY_COMPLETE=1'
exit 0
