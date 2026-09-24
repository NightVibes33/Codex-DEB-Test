#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

DIR=/var/mobile/Library/Logs/CrashReporter/Retired
echo '=== RETIRED SPRINGBOARD CRASH EXTRACTION ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
ls -lt "$DIR"/SpringBoard-*.ips 2>/dev/null | head -n 20 || true

echo
echo '=== FOUR CRASH SIGNATURES ==='
for f in "$DIR"/SpringBoard-2026-09-24-015355.ips "$DIR"/SpringBoard-2026-09-24-015406.ips "$DIR"/SpringBoard-2026-09-24-015423.ips "$DIR"/SpringBoard-2026-09-24-015438.ips; do
  [ -f "$f" ] || continue
  echo "===== FILE=$f ====="
  wc -c "$f" 2>/dev/null || true
  sed -n '1p' "$f" 2>/dev/null | fold -w 3000
  tr ',' '\n' < "$f" 2>/dev/null \
    | grep -a -Ei 'exception|termination|reason|signal|faultingThread|triggered|lastException|abort|namespace|procName|procPath' \
    | cut -c 1-2500 \
    | head -n 160 || true
  echo '--- referenced jailbreak dylibs ---'
  tr ',' '\n' < "$f" 2>/dev/null \
    | grep -a -E '/var/jb/[^"]*\.dylib|/var/jb/[^"]*TweakInject[^"]*|/var/jb/[^"]*DynamicLibraries[^"]*' \
    | cut -c 1-2500 \
    | head -n 260 || true
done

NEWEST="$DIR/SpringBoard-2026-09-24-015438.ips"
if [ -f "$NEWEST" ]; then
  echo '=== NEWEST_CRASH_BASE64_BEGIN ==='
  base64 "$NEWEST" 2>/dev/null
  echo '=== NEWEST_CRASH_BASE64_END ==='
fi

echo 'RETIRED_CRASH_EXTRACTION_COMPLETE=1'
exit 0
