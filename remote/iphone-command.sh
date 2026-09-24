#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile
TI=/var/jb/usr/lib/TweakInject
STAGED=/var/jb/usr/local/share/ZZCircleAppsCompat.dylib
MARKER=/var/mobile/Media/circleapps-final-fix.marker

echo '=== FINAL CIRCLEAPPS + SPRINGBOARD INJECTION VERIFY ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true

echo
echo '=== INSTALL REAL CIRCLEAPPS GUARD ==='
test -s "$STAGED" || { echo 'FATAL|staged-guard-missing'; exit 20; }
cp -f "$STAGED" "$TI/ZZCircleAppsCompat.dylib"
chmod 755 "$TI/ZZCircleAppsCompat.dylib"
cat > "$TI/ZZCircleAppsCompat.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Filter</key><dict><key>Bundles</key><array><string>com.apple.springboard</string></array></dict>
</dict></plist>
PLIST
chmod 644 "$TI/ZZCircleAppsCompat.plist"
plutil -lint "$TI/ZZCircleAppsCompat.plist" 2>&1 || exit 21
file "$TI/ZZCircleAppsCompat.dylib" 2>/dev/null || true

for ext in dylib plist; do
  if [ -e "$TI/CircleAppsiPhone.$ext.disabled" ]; then
    mv -f "$TI/CircleAppsiPhone.$ext.disabled" "$TI/CircleAppsiPhone.$ext"
  fi
done
chmod 755 "$TI/CircleAppsiPhone.dylib" 2>/dev/null || true
chmod 644 "$TI/CircleAppsiPhone.plist" 2>/dev/null || true
test -f "$TI/CircleAppsiPhone.dylib" || { echo 'FATAL|circleapps-dylib-missing'; exit 22; }
test -f "$TI/CircleAppsiPhone.plist" || { echo 'FATAL|circleapps-filter-missing'; exit 23; }
echo 'circleapps_enabled=yes'
echo 'circleapps_guard_installed=yes'

echo
echo '=== EXPECTED SPRINGBOARD TWEAKS ==='
EXP=/tmp/sb-expected.$$
: > "$EXP"
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  strings "$p" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard' || continue
  n="$(basename "$p" .plist)"
  [ -f "$TI/$n.dylib" ] || continue
  echo "$n" >> "$EXP"
done
sort -u "$EXP" -o "$EXP"
cat "$EXP"
echo "expected_springboard_tweaks=$(wc -l < "$EXP" | tr -d ' ')"

echo
echo '=== PRE-RESTART SAFE MODE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
PRE="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pre=$PRE"

echo
echo '=== ONE SPRINGBOARD RESTART ==='
touch "$MARKER"
killall cfprefsd 2>/dev/null || true
killall -9 SpringBoard 2>/dev/null || true
sleep 10
P1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_t10=$P1"
sleep 25
P2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_t35=$P2"

echo
echo '=== NEW SPRINGBOARD CRASHES ==='
NEWCR=0
for root in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
  [ -d "$root" ] || continue
  for f in "$root"/SpringBoard-*.ips; do
    [ -f "$f" ] || continue
    [ "$f" -nt "$MARKER" ] || continue
    NEWCR=$((NEWCR+1))
    echo "NEW_CRASH=$f"
    tr ',' '\n' < "$f" 2>/dev/null       | grep -a -Ei 'exception|signal|CircleApps|ZZCircleAppsCompat|insertObject|faultingThread'       | cut -c 1-1800 | head -n 120 || true
  done
done
echo "new_springboard_crashes=$NEWCR"

echo
echo '=== GUARD LOG ==='
if command -v log >/dev/null 2>&1; then
  log show --last 3m --style compact 2>/dev/null     | grep -F 'ZZCircleAppsCompat' | tail -n 50 || true
fi

echo
echo '=== LIVE LOAD STATE ==='
LOADED=/tmp/sb-loaded.$$
: > "$LOADED"
if [ -n "$P2" ] && command -v vmmap >/dev/null 2>&1; then
  vmmap "$P2" 2>/dev/null     | grep -E '/(TweakInject|DynamicLibraries)/.*\.dylib'     | sed -E 's#^.*(/TweakInject/|/DynamicLibraries/)##; s#\.dylib.*$##'     | sed 's#^.*/##' | sort -u > "$LOADED" || true
elif [ -n "$P2" ] && command -v lsof >/dev/null 2>&1; then
  lsof -p "$P2" 2>/dev/null     | grep -E '/(TweakInject|DynamicLibraries)/.*\.dylib'     | sed -E 's#^.*(/TweakInject/|/DynamicLibraries/)##; s#\.dylib.*$##'     | sed 's#^.*/##' | sort -u > "$LOADED" || true
else
  echo 'live_image_tool=unavailable'
fi
if [ -s "$LOADED" ]; then
  echo '--- loaded ---'
  cat "$LOADED"
  echo '--- expected but not observed ---'
  while IFS= read -r n; do
    grep -Fxq "$n" "$LOADED" || echo "NOT_OBSERVED=$n"
  done < "$EXP"
fi

echo
echo '=== FINAL STATE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true
if [ -n "$P1" ] && [ "$P1" = "$P2" ] && [ "$NEWCR" -eq 0 ]; then
  echo 'springboard_stable_35s=yes'
else
  echo 'springboard_stable_35s=no'
fi

if [ "$NEWCR" -eq 0 ] && [ -n "$P1" ] && [ "$P1" = "$P2" ]; then
  echo 'CIRCLEAPPS_FIX_RESULT=PASS'
else
  echo 'CIRCLEAPPS_FIX_RESULT=FAIL'
fi

rm -f "$EXP" "$LOADED"
echo 'FINAL_CIRCLEAPPS_VERIFY_COMPLETE=1'
exit 0
