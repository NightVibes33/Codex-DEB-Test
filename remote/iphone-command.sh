#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
TI=/var/jb/usr/lib/TweakInject

printf '%s\n' '=== IPHONE TWEAK FILTER RAW DIAGNOSTIC ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== AVAILABLE TOOLS =====\n'
for c in base64 strings file otool lipo jtool jtool2 nm defaults plutil; do
  p=$(command -v "$c" 2>/dev/null)
  [ -n "$p" ] && echo "$c=$p" || echo "$c=MISSING"
done

printf '\n===== FILTER PLISTS BASE64 =====\n'
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  echo "FILTER_BEGIN=$(basename "$p")"
  if command -v base64 >/dev/null 2>&1; then
    base64 "$p" 2>/dev/null | tr -d '\r\n'
    echo
  else
    echo 'BASE64_TOOL_MISSING'
  fi
  echo "FILTER_END=$(basename "$p")"
done

printf '\n===== DYLIB MACH-O ARCHITECTURE =====\n'
for d in "$TI"/*.dylib; do
  [ -e "$d" ] || [ -L "$d" ] || continue
  echo "DYLIB=$(basename "$d")"
  if command -v file >/dev/null 2>&1; then file "$d" 2>&1; fi
  if command -v lipo >/dev/null 2>&1; then lipo -info "$d" 2>&1; fi
  if command -v otool >/dev/null 2>&1; then otool -hv "$d" 2>&1 | head -n 8; fi
done

printf '\n===== DOPAMINE / ELLEKIT PREFS BASE64 =====\n'
for p in /var/mobile/Library/Preferences/com.opa334.Dopamine.plist /var/mobile/Library/Preferences/com.opa334.ElleKit.plist /var/jb/var/mobile/Library/Preferences/com.opa334.Dopamine.plist; do
  [ -f "$p" ] || continue
  echo "PREF_BEGIN=$p"
  base64 "$p" 2>/dev/null | tr -d '\r\n'
  echo
  echo "PREF_END=$p"
done

printf '\n===== ACTIVE SERVICES =====\n'
launchctl list 2>/dev/null | grep -Ei 'ellekit|rocket|dopamine|substrate|substitute' || true

printf '\n===== TARGET PROCESSES =====\n'
ps -A -o pid=,ppid=,%cpu=,%mem=,comm= 2>/dev/null | grep -Ei 'SpringBoard|Preferences|installd|frontboard|gboard|filza|icleaner|maintenanced|dasd|Arthur|AppStore|store' || true

printf '%s\n' '=== END IPHONE TWEAK FILTER RAW DIAGNOSTIC ==='
