#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

TI=/var/jb/usr/lib/TweakInject
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="/var/mobile/Media/TweakRepair-$STAMP"
mkdir -p "$BACKUP"

echo '=== FINAL TWEAK REPAIR PASS ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null
printf 'model='; sysctl -n hw.model 2>/dev/null
echo "backup=$BACKUP"

echo
echo '=== PRE-STATE ==='
printf '_MSSafeMode='; launchctl getenv _MSSafeMode 2>/dev/null || true
printf '_SafeMode='; launchctl getenv _SafeMode 2>/dev/null || true
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true

echo
echo '=== CIRCLEAPPS CONFIRMED PACKAGE ==='
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n'   com.sugiuta.circleapps15 com.opa334.altlist ws.hbang.common preferenceloader ellekit 2>/dev/null || true

echo
echo '=== CIRCLEAPPS PREFERENCE REPAIR ==='
PB=/var/jb/usr/libexec/PlistBuddy
PREF_FOUND=0
for f in /var/mobile/Library/Preferences/*.plist; do
  [ -f "$f" ] || continue
  strings "$f" 2>/dev/null | grep -q 'selectedApplications' || continue
  PREF_FOUND=$((PREF_FOUND+1))
  echo "circleapps_pref=$f"
  cp -p "$f" "$BACKUP/$(basename "$f").before" 2>/dev/null || true
  echo '--- selectedApplications before ---'
  plutil -p "$f" 2>/dev/null | grep -A40 -B4 'selectedApplications' || true
  if [ -x "$PB" ]; then
    "$PB" -c 'Delete :selectedApplications' "$f" 2>/dev/null || true
  else
    plutil -remove selectedApplications "$f" >/dev/null 2>&1 || true
  fi
  echo '--- selectedApplications after ---'
  if plutil -p "$f" 2>/dev/null | grep -q 'selectedApplications'; then
    echo 'selectedApplications=still-present'
  else
    echo 'selectedApplications=removed'
  fi
done
echo "circleapps_preference_files_repaired=$PREF_FOUND"

echo
echo '=== RESTORE CIRCLEAPPS INJECTION ==='
for ext in dylib plist; do
  if [ -e "$TI/CircleAppsiPhone.$ext.disabled" ]; then
    cp -p "$TI/CircleAppsiPhone.$ext.disabled" "$BACKUP/CircleAppsiPhone.$ext.disabled" 2>/dev/null || true
    mv -f "$TI/CircleAppsiPhone.$ext.disabled" "$TI/CircleAppsiPhone.$ext"
    echo "restored=$TI/CircleAppsiPhone.$ext"
  fi
done
chmod 755 "$TI/CircleAppsiPhone.dylib" 2>/dev/null || true
chmod 644 "$TI/CircleAppsiPhone.plist" 2>/dev/null || true
ls -la "$TI"/CircleAppsiPhone* 2>/dev/null || true

echo
echo '=== CHOICY SPRINGBOARD / GLOBAL RULES ==='
for f in /var/mobile/Library/Preferences/com.opa334.choicy.plist /var/mobile/Library/Preferences/com.opa334.choicyprefs.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || true
done

echo
echo '=== ACTIVE TWEAK STRUCTURAL AUDIT ==='
COUNT=0
for d in "$TI"/*.dylib; do
  [ -f "$d" ] || continue
  COUNT=$((COUNT+1))
  n="$(basename "$d" .dylib)"
  p="$TI/$n.plist"
  info="$(file "$d" 2>/dev/null)"
  owner="$(dpkg-query -S "${d#/var/jb}" 2>/dev/null | head -n1 | cut -d: -f1)"
  [ -n "$owner" ] || owner=unknown
  echo "TWEAK|$n|owner=$owner|$info"

  if [ ! -x "$d" ]; then
    chmod 755 "$d" 2>/dev/null && echo "FIXED|exec-permission|$n"
  fi
  if [ ! -f "$p" ]; then
    echo "ISSUE|missing-filter|$n"
  else
    chmod 644 "$p" 2>/dev/null || true
    plutil -lint "$p" >/dev/null 2>&1 || echo "ISSUE|malformed-filter|$n"
  fi
  if echo "$info" | grep -q 'arm64e' && ! echo "$info" | grep -Eq '\[arm64:| arm64([^e]|$)'; then
    echo "ISSUE|arm64e-only|$n"
  fi
done
echo "enabled_tweak_dylibs=$COUNT"

echo
echo '=== DISABLED PAYLOADS STILL PRESENT ==='
find "$TI" -maxdepth 1 -type f -name '*.disabled' -print 2>/dev/null | sort || true

echo
echo '=== SUPPORT PACKAGE HEALTH ==='
dpkg --audit 2>&1 || true
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null  | grep -Ei 'circleapps|choicy|cephei|altlist|ellekit|substrate|rocketbootstrap|applist|snowboard|crane|cylinder|dynamicstage|little16|interactive|speedster|waktos|stella|sonus|explosive|fivecolumns|exsto|tweakhub|sentinel'  | sort || true

echo
echo '=== DEPENDENCY AUDIT IF OTOOL EXISTS ==='
if command -v otool >/dev/null 2>&1; then
  for d in "$TI"/*.dylib; do
    [ -f "$d" ] || continue
    n="$(basename "$d" .dylib)"
    otool -L "$d" 2>/dev/null | tail -n +2 | awk '{print $1}' | while IFS= read -r dep; do
      case "$dep" in
        /System/*|/usr/lib/libSystem*|/usr/lib/libobjc*|/usr/lib/libc++*|/usr/lib/libz*|/usr/lib/libsqlite3*|@loader_path/*|@executable_path/*) continue ;;
        @rpath/*)
          rel="${dep#@rpath/}"
          base="$(basename "$rel")"
          [ -e "/var/jb/Library/Frameworks/$rel" ] || [ -e "/var/jb/usr/lib/$rel" ] || [ -e "/var/jb/usr/lib/$base" ]             || echo "ISSUE|unresolved-rpath|$n|$dep"
          ;;
        /Library/*|/usr/lib/*)
          [ -e "$dep" ] || [ -e "/var/jb$dep" ] || echo "ISSUE|missing-dependency|$n|$dep"
          ;;
      esac
    done
  done
else
  echo 'otool=missing-on-device'
fi

echo
echo '=== SINGLE SPRINGBOARD RESTART ==='
MARKER="$BACKUP/restart.marker"
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
    tr ',' '\n' < "$f" 2>/dev/null       | grep -a -Ei 'exception|signal|CircleApps|TweakInject|insertObject|faultingThread'       | cut -c 1-1400 | head -n 120 || true
  done
done
echo "new_springboard_crashes=$NEWCR"

echo
echo '=== POST-STATE ==='
printf '_MSSafeMode='; launchctl getenv _MSSafeMode 2>/dev/null || true
printf '_SafeMode='; launchctl getenv _SafeMode 2>/dev/null || true
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true
if [ -n "$P1" ] && [ "$P1" = "$P2" ] && [ "$NEWCR" -eq 0 ]; then
  echo 'springboard_stable_30s=yes'
else
  echo 'springboard_stable_30s=no'
fi

echo
echo '=== LIVE SPRINGBOARD TWEAK IMAGES ==='
if [ -n "$P2" ] && command -v vmmap >/dev/null 2>&1; then
  vmmap "$P2" 2>/dev/null     | grep -E '/(TweakInject|MobileSubstrate/DynamicLibraries)/.*\.dylib'     | sed -E 's#^.*(/TweakInject/|/DynamicLibraries/)##'     | sort -u | head -n 400 || true
elif [ -n "$P2" ] && command -v lsof >/dev/null 2>&1; then
  lsof -p "$P2" 2>/dev/null     | grep -E '/(TweakInject|MobileSubstrate/DynamicLibraries)/.*\.dylib'     | sed -E 's#^.*(/TweakInject/|/DynamicLibraries/)##'     | sort -u | head -n 400 || true
else
  echo 'live_image_tool=unavailable'
fi

echo 'FINAL_TWEAK_REPAIR_COMPLETE=1'
exit 0
