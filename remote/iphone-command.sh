#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="/var/mobile/Media/TweakRepair-$STAMP"
TI="/var/jb/usr/lib/TweakInject"
PREF="/var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist"
MARKER="$BACKUP/restart.marker"
mkdir -p "$BACKUP"

echo '=== CIRCLEAPPS REAL REPAIR + TWEAK HEALTH PASS ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
echo "backup=$BACKUP"

echo
echo '=== PRE-STATE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n'   com.sugiuta.circleapps15 ws.hbang.common com.opa334.altlist preferenceloader ellekit 2>/dev/null || true

echo
echo '=== BACKUP CIRCLEAPPS STATE ==='
[ -f "$PREF" ] && cp -p "$PREF" "$BACKUP/com.sugiuta.circleapps15.plist.before" 2>/dev/null || true
for f in "$TI"/CircleAppsiPhone.dylib "$TI"/CircleAppsiPhone.plist          "$TI"/CircleAppsiPhone.dylib.disabled "$TI"/CircleAppsiPhone.plist.disabled; do
  [ -e "$f" ] && cp -p "$f" "$BACKUP/$(basename "$f").before" 2>/dev/null || true
done
[ -f "$PREF" ] && { echo '--- CircleApps prefs before ---'; plutil -p "$PREF" 2>/dev/null || true; }

echo
echo '=== INSTALL CIRCLEAPPS COMPATIBILITY GUARD ==='
STAGED="/var/jb/usr/local/share/ZZCircleAppsCompat.dylib"
if [ ! -s "$STAGED" ]; then
  echo 'FATAL|compat-guard-stage-missing'
  exit 21
fi
cp -f "$STAGED" "$TI/ZZCircleAppsCompat.dylib"
chmod 755 "$TI/ZZCircleAppsCompat.dylib"
cat > "$TI/ZZCircleAppsCompat.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Filter</key>
  <dict>
    <key>Bundles</key>
    <array>
      <string>com.apple.springboard</string>
    </array>
  </dict>
</dict>
</plist>
PLIST
chmod 644 "$TI/ZZCircleAppsCompat.plist"
plutil -lint "$TI/ZZCircleAppsCompat.plist" 2>&1 || true
file "$TI/ZZCircleAppsCompat.dylib" 2>/dev/null || true
echo 'compat_guard_installed=yes'

echo
echo '=== RE-ENABLE OFFICIAL CIRCLEAPPS ==='
for ext in dylib plist; do
  if [ -e "$TI/CircleAppsiPhone.$ext.disabled" ]; then
    mv -f "$TI/CircleAppsiPhone.$ext.disabled" "$TI/CircleAppsiPhone.$ext"
    echo "restored=$TI/CircleAppsiPhone.$ext"
  fi
done
chmod 755 "$TI/CircleAppsiPhone.dylib" 2>/dev/null || true
chmod 644 "$TI/CircleAppsiPhone.plist" 2>/dev/null || true
ls -la "$TI"/CircleAppsiPhone* "$TI"/ZZCircleAppsCompat* 2>/dev/null || true
if [ ! -f "$TI/CircleAppsiPhone.dylib" ] || [ ! -f "$TI/CircleAppsiPhone.plist" ]; then
  echo 'FATAL|circleapps-not-restored'
  exit 22
fi
echo 'circleapps_enabled=yes'

echo
echo '=== GENERIC TWEAK FILE REPAIRS ==='
PERM_FIXED=0
BAD_FILTERS=0
MISSING_FILTERS=0
for d in "$TI"/*.dylib; do
  [ -f "$d" ] || continue
  n="$(basename "$d" .dylib)"
  p="$TI/$n.plist"
  if [ ! -x "$d" ]; then
    chmod 755 "$d" 2>/dev/null && PERM_FIXED=$((PERM_FIXED+1)) && echo "FIXED|exec-bit|$n"
  fi
  if [ -f "$p" ]; then
    chmod 644 "$p" 2>/dev/null || true
    if ! plutil -lint "$p" >/dev/null 2>&1; then
      BAD_FILTERS=$((BAD_FILTERS+1))
      echo "ISSUE|malformed-filter|$n|$p"
    fi
  else
    MISSING_FILTERS=$((MISSING_FILTERS+1))
    echo "ISSUE|missing-filter|$n"
  fi
done
echo "permission_repairs=$PERM_FIXED"
echo "malformed_filters=$BAD_FILTERS"
echo "missing_filters=$MISSING_FILTERS"

echo
echo '=== CHOICY SPRINGBOARD / APP INJECTION RULES ==='
for f in /var/mobile/Library/Preferences/com.opa334.choicy.plist /var/mobile/Library/Preferences/com.opa334.choicyprefs.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || true
done
defaults read com.opa334.choicy 2>/dev/null || true

echo
echo '=== DISABLED PAYLOADS NOT CIRCLEAPPS ==='
find "$TI" -maxdepth 1 -type f -name '*.disabled' -print 2>/dev/null | sort || true

echo
echo '=== PACKAGE DATABASE HEALTH ==='
dpkg --audit 2>&1 || true

echo
echo '=== ARCHITECTURE AUDIT ==='
for d in "$TI"/*.dylib; do
  [ -f "$d" ] || continue
  info="$(file "$d" 2>/dev/null)"
  n="$(basename "$d")"
  echo "ARCH|$n|$info"
  if echo "$info" | grep -q 'arm64e' && ! echo "$info" | grep -Eq '\[arm64:| arm64([^eA-Za-z0-9]|$)'; then
    echo "ISSUE|arm64e-only-on-arm64-device|$n"
  fi
done

echo
echo '=== LINKED DEPENDENCY AUDIT ==='
if command -v otool >/dev/null 2>&1; then
  echo "otool=$(command -v otool)"
  for d in "$TI"/*.dylib; do
    [ -f "$d" ] || continue
    n="$(basename "$d")"
    otool -L "$d" 2>/dev/null | tail -n +2 | awk '{print $1}' | while IFS= read -r dep; do
      case "$dep" in
        /System/*|/usr/lib/libSystem*|/usr/lib/libobjc*|/usr/lib/libc++*|/usr/lib/libz*|/usr/lib/libsqlite3*|/usr/lib/libxml2*|/usr/lib/libarchive*|/usr/lib/libcompression*|@loader_path/*|@executable_path/*)
          continue ;;
        @rpath/*)
          rel="${dep#@rpath/}"
          base="$(basename "$rel")"
          if [ ! -e "/var/jb/Library/Frameworks/$rel" ] && [ ! -e "/var/jb/usr/lib/$rel" ] && [ ! -e "/var/jb/usr/lib/$base" ]; then
            echo "ISSUE|unresolved-rpath|$n|$dep"
          fi
          ;;
        /Library/*|/usr/lib/*)
          if [ ! -e "$dep" ] && [ ! -e "/var/jb$dep" ]; then
            echo "ISSUE|missing-dependency|$n|$dep"
          fi
          ;;
      esac
    done
  done
else
  echo 'otool=missing'
fi

echo
echo '=== RESTART SPRINGBOARD WITH CIRCLEAPPS ACTIVE ==='
touch "$MARKER"
PRE="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pre=$PRE"
killall cfprefsd 2>/dev/null || true
killall -9 SpringBoard 2>/dev/null || true
sleep 8
P1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_t8=$P1"
sleep 22
P2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_t30=$P2"

echo
echo '=== POST-REPAIR CRASH CHECK ==='
NEWCR=0
for root in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
  [ -d "$root" ] || continue
  for f in "$root"/SpringBoard-*.ips; do
    [ -f "$f" ] || continue
    [ "$f" -nt "$MARKER" ] || continue
    NEWCR=$((NEWCR+1))
    echo "NEW_CRASH=$f"
    tr ',' '\n' < "$f" 2>/dev/null       | grep -a -Ei 'exception|signal|abort|CircleApps|TweakInject|insertObject|faultingThread'       | cut -c 1-1800 | head -n 100 || true
  done
done
echo "new_springboard_crashes=$NEWCR"

echo
echo '=== POST-REPAIR CIRCLEAPPS PREFS ==='
[ -f "$PREF" ] && plutil -p "$PREF" 2>/dev/null || true

echo
echo '=== LIVE LOAD CHECK ==='
if [ -n "$P2" ] && command -v vmmap >/dev/null 2>&1; then
  vmmap "$P2" 2>/dev/null | grep -E 'CircleApps|ZZCircleAppsCompat|/TweakInject/.*\.dylib' | head -n 400 || true
elif [ -n "$P2" ] && command -v lsof >/dev/null 2>&1; then
  lsof -p "$P2" 2>/dev/null | grep -E 'CircleApps|ZZCircleAppsCompat|/TweakInject/.*\.dylib' | head -n 400 || true
else
  echo 'live_load_probe_unavailable=1'
fi

echo
echo '=== RESULT ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true
if [ -n "$P1" ] && [ "$P1" = "$P2" ] && [ "$NEWCR" -eq 0 ]    && [ -f "$TI/CircleAppsiPhone.dylib" ] && [ -f "$TI/ZZCircleAppsCompat.dylib" ]; then
  echo 'circleapps_repair_result=PASS'
else
  echo 'circleapps_repair_result=FAIL'
fi
echo 'CIRCLEAPPS_REAL_REPAIR_COMPLETE=1'
exit 0
