#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="/var/mobile/Media/TweakRepair-$STAMP"
mkdir -p "$BACKUP"

echo '=== CONSOLIDATED TWEAK REPAIR ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null
printf 'model='; sysctl -n hw.model 2>/dev/null
echo "backup=$BACKUP"

echo
echo '=== INJECTION / SAFE MODE PRE-STATE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' ellekit com.opa334.choicy preferenceloader 2>/dev/null || true
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true

echo
echo '=== CHOICY STATE ==='
defaults read com.opa334.choicy 2>/dev/null || true
for f in /var/mobile/Library/Preferences/com.opa334.choicy.plist /var/mobile/Library/Preferences/com.opa334.choicyprefs.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || true
done

echo
echo '=== CIRCLEAPPS ROOT-CAUSE REPAIR ==='
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' com.sugiuta.circleapps15 com.opa334.altlist ws.hbang.common 2>/dev/null || true
PB=/var/jb/usr/libexec/PlistBuddy
FOUND_PREF=0
for f in /var/mobile/Library/Preferences/*.plist; do
  [ -f "$f" ] || continue
  if strings "$f" 2>/dev/null | grep -q 'selectedApplications'; then
    FOUND_PREF=1
    echo "circleapps_pref=$f"
    cp -p "$f" "$BACKUP/$(basename "$f").before" 2>/dev/null || true
    echo '--- before ---'
    plutil -p "$f" 2>/dev/null | grep -A20 -B4 'selectedApplications' || true
    if [ -x "$PB" ]; then
      "$PB" -c 'Delete :selectedApplications' "$f" 2>/dev/null || true
    else
      plutil -remove selectedApplications "$f" >/dev/null 2>&1 || true
    fi
    echo '--- after ---'
    plutil -p "$f" 2>/dev/null | grep -A10 -B4 'selectedApplications' || echo 'selectedApplications=removed'
  fi
done
echo "circleapps_pref_files_found=$FOUND_PREF"

TI=/var/jb/usr/lib/TweakInject
for ext in dylib plist; do
  if [ -e "$TI/CircleAppsiPhone.$ext.disabled" ]; then
    cp -p "$TI/CircleAppsiPhone.$ext.disabled" "$BACKUP/CircleAppsiPhone.$ext.disabled" 2>/dev/null || true
    mv -f "$TI/CircleAppsiPhone.$ext.disabled" "$TI/CircleAppsiPhone.$ext"
    echo "circleapps_restored=$TI/CircleAppsiPhone.$ext"
  fi
done
chmod 755 "$TI/CircleAppsiPhone.dylib" 2>/dev/null || true
chmod 644 "$TI/CircleAppsiPhone.plist" 2>/dev/null || true
echo '--- CircleApps active files ---'
ls -la "$TI"/CircleAppsiPhone* 2>/dev/null || true
plutil -p "$TI/CircleAppsiPhone.plist" 2>/dev/null || true

echo
echo '=== FILE / FILTER / ARCH REPAIR AUDIT ==='
ISSUES=0
FIXED_PERMS=0
ACTIVE=0
for d in "$TI"/*.dylib; do
  [ -f "$d" ] || continue
  ACTIVE=$((ACTIVE+1))
  n="$(basename "$d" .dylib)"
  p="$TI/$n.plist"
  fi="$(file "$d" 2>/dev/null)"
  owner="$(dpkg-query -S "${d#/var/jb}" 2>/dev/null | head -n1 | cut -d: -f1)"
  [ -n "$owner" ] || owner=unknown
  echo "TWEAK|$n|owner=$owner|$fi"
  if [ ! -x "$d" ]; then
    chmod 755 "$d" 2>/dev/null && FIXED_PERMS=$((FIXED_PERMS+1)) && echo "FIXED|exec-bit|$n"
  fi
  if [ ! -f "$p" ]; then
    ISSUES=$((ISSUES+1))
    echo "ISSUE|missing-filter|$n"
  else
    chmod 644 "$p" 2>/dev/null || true
    if ! plutil -lint "$p" >/dev/null 2>&1; then
      ISSUES=$((ISSUES+1))
      echo "ISSUE|malformed-filter|$n|$p"
    fi
  fi
  if echo "$fi" | grep -q 'arm64e' && ! echo "$fi" | grep -Eq '\[arm64:| arm64([^e]|$)'; then
    ISSUES=$((ISSUES+1))
    echo "ISSUE|arm64e-only-on-arm64-device|$n"
  fi
done
echo "active_dylibs=$ACTIVE"
echo "permission_repairs=$FIXED_PERMS"
echo "basic_issue_count=$ISSUES"

echo
echo '=== LINKED DEPENDENCY AUDIT ==='
if command -v otool >/dev/null 2>&1; then
  for d in "$TI"/*.dylib; do
    [ -f "$d" ] || continue
    n="$(basename "$d" .dylib)"
    otool -L "$d" 2>/dev/null | tail -n +2 | awk '{print $1}' | while IFS= read -r dep; do
      case "$dep" in
        /System/*|/usr/lib/libSystem*|/usr/lib/libobjc*|/usr/lib/libc++*|/usr/lib/libz*|/usr/lib/libsqlite3*|/usr/lib/libxml2*|/usr/lib/libarchive*|/usr/lib/libcompression*|@loader_path/*|@executable_path/*)
          continue ;;
        @rpath/*)
          rel="${dep#@rpath/}"
          if [ ! -e "/var/jb/Library/Frameworks/$rel" ] && [ ! -e "/var/jb/usr/lib/$rel" ]; then
            base="$(basename "$rel")"
            if [ ! -e "/var/jb/usr/lib/$base" ]; then
              echo "ISSUE|unresolved-rpath|$n|$dep"
            fi
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
echo '=== DISABLED PAYLOADS AFTER REPAIR ==='
find "$TI" -maxdepth 1 -type f -name '*.disabled' -print 2>/dev/null | sort || true

echo
echo '=== PACKAGE DATABASE HEALTH ==='
dpkg --audit 2>&1 || true
apt-get check 2>&1 | tail -n 80 || true

echo
echo '=== SPRINGBOARD RESTART ONCE (NO SBRELOAD) ==='
MARKER="$BACKUP/restart.marker"
touch "$MARKER"
PRE="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pre=$PRE"
killall cfprefsd 2>/dev/null || true
killall -9 SpringBoard 2>/dev/null || true
sleep 5
P1="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_t5=$P1"
sleep 20
P2="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_t25=$P2"

echo
echo '=== POST-REPAIR CRASH CHECK ==='
for root in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 1 -type f -name 'SpringBoard-*.ips' -newer "$MARKER" -print 2>/dev/null | while IFS= read -r f; do
    echo "NEW_CRASH=$f"
    strings "$f" 2>/dev/null | grep -Ei 'CircleApps|TweakInject|exception|abort|insertObject|safe.?mode' | head -n 80 || true
  done
done
NEWCR="$(find /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired -maxdepth 1 -type f -name 'SpringBoard-*.ips' -newer "$MARKER" -print 2>/dev/null | wc -l | tr -d ' ')"
echo "new_springboard_crashes=$NEWCR"

echo
echo '=== POST-REPAIR INJECTION STATE ==='
echo "_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "_SafeMode=$(launchctl getenv _SafeMode 2>/dev/null)"
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true
if [ -n "$P1" ] && [ "$P1" = "$P2" ] && [ "$NEWCR" = 0 ]; then
  echo 'springboard_stable=yes'
else
  echo 'springboard_stable=no'
fi

if [ -n "$P2" ]; then
  if command -v vmmap >/dev/null 2>&1; then
    echo '=== LOADED TWEAKS IN SPRINGBOARD ==='
    vmmap "$P2" 2>/dev/null | grep '/TweakInject/.*\.dylib' | sed 's#^.*/TweakInject/##' | sort -u | head -n 300 || true
  elif command -v lsof >/dev/null 2>&1; then
    echo '=== LOADED TWEAK FILES IN SPRINGBOARD ==='
    lsof -p "$P2" 2>/dev/null | grep '/TweakInject/.*\.dylib' | sed 's#^.*/TweakInject/##' | sort -u | head -n 300 || true
  fi
fi

echo 'CONSOLIDATED_TWEAK_REPAIR_COMPLETE=1'
exit 0
