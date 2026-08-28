#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
TI=/var/jb/usr/lib/TweakInject

echo '=== IPHONE TWEAK BINARY COMPATIBILITY CHECK ==='
echo "captured_at=$(date 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== MACH-O FIRST 32 BYTES =====\n'
for d in "$TI"/*.dylib; do
  [ -e "$d" ] || [ -L "$d" ] || continue
  echo "HEADER_BEGIN=$(basename "$d")"
  dd if="$d" bs=32 count=1 2>/dev/null | base64 2>/dev/null | tr -d '\r\n'
  echo
  echo "HEADER_END=$(basename "$d")"
done

printf '\n===== TARGET APP DIRECTORY NAMES =====\n'
find /var/containers/Bundle/Application -maxdepth 3 -type d -name '*.app' -print 2>/dev/null | grep -Ei 'Gboard|Keyboard|Arthur|Browser|Filza|iCleaner|Store' | sort || true
find /var/jb/Applications -maxdepth 2 -type d -name '*.app' -print 2>/dev/null | grep -Ei 'Filza|iCleaner|Tweak|Sileo|Zebra' | sort || true

printf '\n===== EXACT SYSTEM TARGETS =====\n'
for exe in SpringBoard dasd appstored installd mmaintenanced lockdownd MobileGestaltHelper; do
  echo "TARGET=$exe"
  ps -A -o pid=,comm= 2>/dev/null | grep -E "[ /]${exe}$" || echo 'NOT_RUNNING'
done

echo '=== END IPHONE TWEAK BINARY COMPATIBILITY CHECK ==='
