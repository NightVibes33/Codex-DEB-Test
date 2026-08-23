#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo '=== Zebra tweak injection inventory ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'

echo '--- injector packages ---'
dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null | grep -Ei 'ellekit|choicy|substrate|substitute|libhooker' || true

for D in /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/usr/lib/TweakInject; do
  echo "--- directory: $D ---"
  [ -d "$D" ] || { echo missing; continue; }
  find "$D" -maxdepth 1 -type f \( -name '*.plist' -o -name '*.dylib' \) -print 2>/dev/null | sort
  echo "--- plist filters in $D ---"
  for p in "$D"/*.plist; do
    [ -f "$p" ] || continue
    echo "### $p"
    if command -v plutil >/dev/null 2>&1; then
      plutil -p "$p" 2>/dev/null || cat "$p" 2>/dev/null || true
    else
      cat "$p" 2>/dev/null || true
    fi
    base="${p%.plist}"
    if [ -f "$base.dylib" ]; then
      owner="$(dpkg -S "$base.dylib" 2>/dev/null | head -n1)"
      echo "owner=${owner:-unknown}"
      ls -lh "$base.dylib" 2>/dev/null || true
    fi
  done
 done

echo '--- filters mentioning Zebra or UIKit ---'
for D in /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/usr/lib/TweakInject; do
  [ -d "$D" ] || continue
  grep -ilE 'xyz\.willy\.Zebra|com\.apple\.UIKit|UIKit|Bundles|Executables|Classes' "$D"/*.plist 2>/dev/null | sort -u || true
done

echo 'zebra_tweak_inventory_complete=true'
exit 0
