#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
TI=/var/jb/usr/lib/TweakInject

printf '%s\n' '=== IPHONE TWEAK FILTER TARGET DIAGNOSTIC ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== FILTER TARGETS =====\n'
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  echo
  echo "--- FILTER=$(basename "$p") ---"
  plutil -p "$p" 2>&1 || strings "$p" 2>/dev/null
 done

printf '\n===== INJECTION FILE PAIRS =====\n'
for d in "$TI"/*.dylib; do
  [ -e "$d" ] || [ -L "$d" ] || continue
  stem=${d%.dylib}
  echo "DYLIB=$(basename "$d") plist=$([ -f "$stem.plist" ] && echo yes || echo NO)"
  ls -l "$d" "$stem.plist" 2>/dev/null
 done

printf '\n===== TARGET PROCESS SNAPSHOT =====\n'
ps -A -o pid=,ppid=,%cpu=,%mem=,comm= 2>/dev/null | grep -Ei 'SpringBoard|Preferences|installd|frontboard|gboard|filza|icleaner|maintenanced|dasd|Arthur|AppStore|store' || true

printf '\n===== INSTALLED USER APP BUNDLE IDS =====\n'
find /var/containers/Bundle/Application -maxdepth 3 -name Info.plist -type f 2>/dev/null | head -n 250 | while IFS= read -r info; do
  bid=$(plutil -extract CFBundleIdentifier raw "$info" 2>/dev/null)
  name=$(plutil -extract CFBundleDisplayName raw "$info" 2>/dev/null)
  [ -n "$name" ] || name=$(plutil -extract CFBundleName raw "$info" 2>/dev/null)
  [ -n "$bid" ] && printf '%s\t%s\n' "$bid" "$name"
done | sort

printf '\n===== JAILBREAK APP BUNDLE IDS =====\n'
find /var/jb/Applications -maxdepth 2 -name Info.plist -type f 2>/dev/null | while IFS= read -r info; do
  bid=$(plutil -extract CFBundleIdentifier raw "$info" 2>/dev/null)
  name=$(plutil -extract CFBundleDisplayName raw "$info" 2>/dev/null)
  [ -n "$name" ] || name=$(plutil -extract CFBundleName raw "$info" 2>/dev/null)
  [ -n "$bid" ] && printf '%s\t%s\n' "$bid" "$name"
done | sort

printf '\n===== ELLEKIT / ROCKETBOOTSTRAP SERVICES =====\n'
launchctl list 2>/dev/null | grep -Ei 'ellekit|rocket|dopamine|substrate|substitute' || true

printf '\n===== RECENT RELEVANT CRASH REPORT NAMES =====\n'
find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f 2>/dev/null | grep -Ei 'SpringBoard|Preferences|installd|Gboard|Filza|iCleaner|Arthur|maintenanced|dasd' | tail -n 80 || true

printf '%s\n' '=== END IPHONE TWEAK FILTER TARGET DIAGNOSTIC ==='
