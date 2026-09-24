#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== FULL TWEAK FUNCTIONALITY AUDIT V2 ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'id='; id

echo
echo '=== INJECTION / SAFE MODE STATE ==='
printf '_MSSafeMode='; launchctl getenv _MSSafeMode 2>/dev/null || true
printf '_SafeMode='; launchctl getenv _SafeMode 2>/dev/null || true
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' ellekit 2>/dev/null || true
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true

echo
echo '=== TWEAK DIRECTORY TOPOLOGY ==='
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  ls -ld "$d" 2>/dev/null || true
  readlink "$d" 2>/dev/null || true
done

echo
echo '=== CIRCLEAPPS PREFS ==='
for f in  /var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist  /var/jb/var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist; do
  [ -f "$f" ] || continue
  echo "===== $f ====="
  ls -lT "$f" 2>/dev/null || true
  plutil -p "$f" 2>/dev/null || true
done
echo '--- defaults domain ---'
defaults read com.sugiuta.circleapps15 2>/dev/null || true

echo
echo '=== INSTALLED APP BUNDLE IDS ==='
TMP=/tmp/installed-bundles.$$
: > "$TMP"
for root in /Applications /var/containers/Bundle/Application /var/jb/Applications; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 3 -type d -name '*.app' 2>/dev/null | while IFS= read -r app; do
    p="$app/Info.plist"
    [ -f "$p" ] || continue
    bid="$(plutil -extract CFBundleIdentifier raw "$p" 2>/dev/null)"
    [ -n "$bid" ] && printf '%s\t%s\n' "$bid" "$app"
  done
done | sort -u > "$TMP"
wc -l "$TMP" 2>/dev/null || true
cat "$TMP" 2>/dev/null || true

echo
echo '=== CIRCLEAPPS SELECTED APP VALIDITY ==='
PREF=/var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist
if [ -f "$PREF" ]; then
  plutil -extract selectedApplications xml1 -o /tmp/circle-selected.plist "$PREF" 2>/dev/null || true
  if [ -s /tmp/circle-selected.plist ]; then
    plutil -p /tmp/circle-selected.plist 2>/dev/null || true
    strings /tmp/circle-selected.plist 2>/dev/null | grep -E '^[A-Za-z0-9][A-Za-z0-9._-]+$' | while IFS= read -r bid; do
      if grep -Fq "$bid	" "$TMP"; then
        echo "selected_valid=$bid"
      else
        echo "selected_stale_or_unknown=$bid"
      fi
    done
  else
    echo 'selectedApplications=missing_or_unreadable'
  fi
fi

echo
echo '=== CHOICY CURRENT RULES ==='
for dom in com.opa334.choicy com.opa334.choicyprefs; do
  echo "--- defaults $dom ---"
  defaults read "$dom" 2>/dev/null || true
done
for f in /var/mobile/Library/Preferences/com.opa334.choicy.plist /var/mobile/Library/Preferences/com.opa334.choicyprefs.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || true
done

echo
echo '=== DISABLED PAYLOADS ==='
find /var/jb/usr/lib/TweakInject -maxdepth 1 -type f \( -name '*.disabled' -o -name '*.dylib.disabled' -o -name '*.plist.disabled' \) -print 2>/dev/null | sort || true

echo
echo '=== MALFORMED FILTERS ==='
for p in /var/jb/usr/lib/TweakInject/*.plist; do
  [ -f "$p" ] || continue
  plutil -lint "$p" >/dev/null 2>&1 || echo "bad_plist=$p"
done

echo
echo '=== TWEAK FILTER TARGETS ==='
for p in /var/jb/usr/lib/TweakInject/*.plist; do
  [ -f "$p" ] || continue
  n="${p##*/}"; n="${n%.plist}"
  printf 'FILTER %s: ' "$n"
  strings "$p" 2>/dev/null | tr '\n' ' ' | cut -c 1-500
  echo
done

echo
echo '=== LOAD TOOL AVAILABILITY ==='
for x in otool vmmap lsof dyld_info file ldid; do
  p="$(command -v "$x" 2>/dev/null)"
  [ -n "$p" ] && echo "$x=$p" || echo "$x=missing"
done

echo
echo '=== ENABLED DYLIB ARCH / DEP CHECK ==='
OTOOL="$(command -v otool 2>/dev/null)"
for d in /var/jb/usr/lib/TweakInject/*.dylib; do
  [ -f "$d" ] || continue
  n="${d##*/}"
  printf 'DYLIB %s | ' "$n"
  file "$d" 2>/dev/null || true
  if [ -n "$OTOOL" ]; then
    bad=0
    "$OTOOL" -L "$d" 2>/dev/null | tail -n +2 | awk '{print $1}' | while IFS= read -r dep; do
      case "$dep" in
        @rpath/*|@loader_path/*|@executable_path/*) continue ;;
      esac
      [ -e "$dep" ] && continue
      [ -e "/var/jb$dep" ] && continue
      case "$dep" in
        /System/*|/usr/lib/libobjc*|/usr/lib/libSystem*|/usr/lib/libc++*|/usr/lib/libsqlite3*|/usr/lib/libz*|/usr/lib/libxml2*|/usr/lib/libcompression*) continue ;;
      esac
      echo "missing_dep=$n::$dep"
    done
  fi
done

echo
echo '=== SPRINGBOARD LIVE TWEAK IMAGES ==='
SBPID="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pid=$SBPID"
if [ -n "$SBPID" ] && command -v vmmap >/dev/null 2>&1; then
  vmmap "$SBPID" 2>/dev/null | grep -E '/var/jb|/private/preboot/.*/procursus' | grep -E 'TweakInject|DynamicLibraries|\.dylib' | head -n 500 || true
elif [ -n "$SBPID" ] && command -v lsof >/dev/null 2>&1; then
  lsof -p "$SBPID" 2>/dev/null | grep -E '/var/jb|/private/preboot/.*/procursus' | grep -E 'TweakInject|DynamicLibraries|\.dylib' | head -n 500 || true
else
  echo 'live_image_probe_unavailable=1'
fi

echo
echo '=== RECENT SPRINGBOARD CRASHES ==='
for dir in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
  [ -d "$dir" ] || continue
  ls -lt "$dir"/SpringBoard-*.ips 2>/dev/null | head -n 20 || true
done

rm -f "$TMP" /tmp/circle-selected.plist
echo 'FULL_TWEAK_FUNCTIONALITY_AUDIT_V2_COMPLETE=1'
exit 0
