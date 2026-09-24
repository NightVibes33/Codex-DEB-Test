#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== IPHONE SAFE MODE TRIAGE ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true

echo
echo '=== PROCESS STATE ==='
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true

echo
echo '=== INJECTION FRAMEWORK ==='
dpkg-query -W -f='${Status} | ${Package} | ${Version}\n' 2>/dev/null | grep -Ei 'ellekit|substrate|substitute|libhooker|dopamine|safe.?mode' || true
ls -la /var/jb/usr/lib/TweakLoader.dylib /var/jb/usr/lib/TweakInject.dylib /var/jb/usr/lib/ellekit/libinjector.dylib 2>/dev/null || true

echo
echo '=== SAFE MODE PREFS / MARKERS ==='
find /var/mobile/Library/Preferences -maxdepth 1 -type f 2>/dev/null | grep -Ei 'safe.?mode|substrate|ellekit|substitute|crash' | head -n 80 || true
for f in /var/mobile/Library/Preferences/*safe* /var/mobile/Library/Preferences/*substrate* /var/mobile/Library/Preferences/*ellekit*; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null | head -n 80 || true
done

echo
echo '=== ACTIVE TWEAK FILES ==='
for d in /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/usr/lib/TweakInject; do
  [ -d "$d" ] || continue
  echo "DIR=$d"
  find "$d" -maxdepth 1 -type f \( -name '*.dylib' -o -name '*.plist' \) -print 2>/dev/null | sort
done

echo
echo '=== TWEAK FILTERS ==='
for d in /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/usr/lib/TweakInject; do
  [ -d "$d" ] || continue
  for f in "$d"/*.plist; do
    [ -f "$f" ] || continue
    echo "--- FILTER $f ---"
    plutil -p "$f" 2>/dev/null | head -n 80 || strings "$f" 2>/dev/null | head -n 80 || true
  done
done

echo
echo '=== DPKG OWNERSHIP FOR TWEAK DIRECTORIES ==='
dpkg-query -S '/var/jb/Library/MobileSubstrate/DynamicLibraries/*' 2>/dev/null | head -n 500 || true
dpkg-query -S '/var/jb/usr/lib/TweakInject/*' 2>/dev/null | head -n 500 || true

echo
echo '=== RECENT PACKAGE LOG ==='
for f in /var/jb/var/log/dpkg.log /var/log/dpkg.log; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  tail -n 160 "$f" 2>/dev/null || true
done

echo
echo '=== LATEST SPRINGBOARD CRASHES ==='
TMP=/tmp/sbcrashes.$$
: > "$TMP"
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 1 -type f \( -name 'SpringBoard-*.ips' -o -name 'SpringBoard-*.crash' \) -print 2>/dev/null
done | sort -u > "$TMP"
CRASHES="$(ls -t $(cat "$TMP" 2>/dev/null) 2>/dev/null | head -n 5)"
for f in $CRASHES; do
  [ -f "$f" ] || continue
  echo "===== CRASH=$f ====="
  echo '--- metadata ---'
  sed -n '1p' "$f" 2>/dev/null | cut -c 1-3000 || true
  echo '--- key fields ---'
  tr ',' '\n' < "$f" 2>/dev/null | grep -a -Ei 'procName|exception|termination|reason|signal|faultingThread|triggered|lastException|abort|namespace|watchdog' | cut -c 1-2200 | head -n 120 || true
  echo '--- jailbreak / injected image fields ---'
  tr ',' '\n' < "$f" 2>/dev/null | grep -a -Ei '/var/jb|DynamicLibraries|TweakInject|MobileSubstrate|ellekit|substrate|substitute|\.dylib' | cut -c 1-2200 | head -n 220 || true
done
rm -f "$TMP"

echo 'IPHONE_SAFE_MODE_TRIAGE_COMPLETE=1'
exit 0
