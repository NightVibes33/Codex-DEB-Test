#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== IPHONE SAFE MODE FAST TRIAGE ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
echo '--- SpringBoard ---'
ps ax 2>/dev/null | grep '[S]pringBoard' || true
echo '--- injection runtime ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version}\n' 2>/dev/null | grep -Ei 'ellekit|substrate|substitute|libhooker|dopamine' || true

echo
echo '=== SPRINGBOARD-TARGETED TWEAKS ==='
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  [ -d "$d" ] || continue
  for p in "$d"/*.plist; do
    [ -f "$p" ] || continue
    if strings "$p" 2>/dev/null | grep -Eqi 'SpringBoard|com\.apple\.springboard|Bundles.*SpringBoard'; then
      b="${p%.plist}"
      echo "--- TARGET $p ---"
      strings "$p" 2>/dev/null | head -n 80
      [ -f "$b.dylib" ] && ls -lT "$b.dylib" 2>/dev/null || ls -l "$b.dylib" 2>/dev/null || true
    fi
  done
done

echo
echo '=== NEWEST TWEAK FILES ==='
ls -lt /var/jb/usr/lib/TweakInject 2>/dev/null | head -n 120 || true

echo
echo '=== RECENT DPKG CHANGES ==='
for f in /var/jb/var/log/dpkg.log /var/log/dpkg.log; do
  [ -f "$f" ] || continue
  tail -n 120 "$f" 2>/dev/null
done

echo
echo '=== LATEST SPRINGBOARD CRASH SUMMARY ==='
TMP=/tmp/sbcrash.$$
: > "$TMP"
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 1 -type f \( -name 'SpringBoard-*.ips' -o -name 'SpringBoard-*.crash' \) -print 2>/dev/null
done | sort -u > "$TMP"
for f in $(ls -t $(cat "$TMP" 2>/dev/null) 2>/dev/null | head -n 3); do
  [ -f "$f" ] || continue
  echo "===== CRASH=$f ====="
  sed -n '1p' "$f" 2>/dev/null | cut -c 1-2500
  echo '--- exception / termination / triggered thread fields ---'
  tr ',' '\n' < "$f" 2>/dev/null \
    | grep -a -Ei 'exception|termination|reason|signal|faultingThread|triggered|lastException|abort|namespace' \
    | cut -c 1-1800 | head -n 100
  echo '--- jailbreak dylibs referenced by crash ---'
  tr ',' '\n' < "$f" 2>/dev/null \
    | grep -a -E '(/var/jb/[^"]*\.dylib|/var/jb/usr/lib/TweakInject/[^"]*|/var/jb/Library/MobileSubstrate/DynamicLibraries/[^"]*)' \
    | cut -c 1-2000 | head -n 180
done
rm -f "$TMP"

echo
echo '=== SAFE MODE MARKERS ==='
find /var/mobile/Library/Preferences -maxdepth 1 -type f 2>/dev/null | grep -Ei 'safe.?mode|substrate|ellekit|substitute' | head -n 50 || true

echo 'IPHONE_SAFE_MODE_FAST_TRIAGE_COMPLETE=1'
exit 0
