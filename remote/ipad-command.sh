#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
D=/var/jb/usr/lib/TweakInject

echo '=== Compact tweak filters relevant to Zebra ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
readlink /var/jb/Library/MobileSubstrate/DynamicLibraries 2>/dev/null || true

echo '--- all filters one line ---'
for p in "$D"/*.plist; do
  [ -f "$p" ] || continue
  n="$(basename "$p" .plist)"
  if command -v plutil >/dev/null 2>&1; then
    v="$(plutil -p "$p" 2>/dev/null | tr '\n\t' '  ' | tr -s ' ')"
  else
    v="$(strings "$p" 2>/dev/null | tr '\n\t' '  ' | tr -s ' ')"
  fi
  [ -n "$v" ] || v="$(cat "$p" 2>/dev/null | tr '\n\t' '  ' | tr -s ' ')"
  printf '%s|%s\n' "$n" "$v"
done

echo '--- direct textual Zebra/UIKit matches ---'
for p in "$D"/*.plist; do
  [ -f "$p" ] || continue
  if strings "$p" 2>/dev/null | grep -Eqi 'xyz\.willy\.Zebra|com\.apple\.UIKit|UIKit'; then
    n="$(basename "$p" .plist)"
    v="$(strings "$p" 2>/dev/null | tr '\n\t' '  ' | tr -s ' ')"
    printf 'MATCH|%s|%s\n' "$n" "$v"
  fi
done

echo 'zebra_compact_filters_complete=true'
exit 0
