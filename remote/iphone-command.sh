#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo '=== IPHONE ROOTLESS TWEAK AUDIT ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

echo '\n===== CORE INJECTION / PREFERENCES ====='
dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\n' 2>/dev/null | grep -Ei 'ellekit|preferenceloader|substrate|substitute|libhooker|snowboard|cephei|applist' || true

echo '\n===== DPKG HEALTH ====='
dpkg --audit 2>&1 || true
apt-get check 2>&1 || true

echo '\n===== PREFERENCELOADER FILES ====='
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -print 2>/dev/null | sort || true

echo '\n===== PREFERENCE BUNDLES ====='
find /var/jb/Library/PreferenceBundles -maxdepth 1 -mindepth 1 -type d -print 2>/dev/null | sort || true

echo '\n===== INJECTION ARTIFACTS + PACKAGE OWNERS ====='
TMP=/tmp/iphone-tweak-pkgs.$$
: > "$TMP"
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  [ -d "$d" ] || continue
  echo "-- $d --"
  find "$d" -maxdepth 1 -type f \( -name '*.dylib' -o -name '*.plist' -o -name '*.disabled' -o -name '*.bak' \) -print 2>/dev/null | sort | while IFS= read -r f; do
    owner=$(dpkg-query -S "$f" 2>/dev/null | head -n1 | cut -d: -f1)
    [ -n "$owner" ] && echo "$owner" >> "$TMP"
    printf '%s\towner=%s\n' "$f" "${owner:-UNOWNED}"
  done
done

for d in /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -mindepth 1 -print 2>/dev/null | sort | while IFS= read -r f; do
    owner=$(dpkg-query -S "$f" 2>/dev/null | head -n1 | cut -d: -f1)
    [ -n "$owner" ] && echo "$owner" >> "$TMP"
  done
done
sort -u "$TMP" -o "$TMP" 2>/dev/null || true

echo '\n===== TWEAK/PREF PACKAGE METADATA ====='
while IFS= read -r p; do
  [ -n "$p" ] || continue
  echo "--- PACKAGE $p ---"
  dpkg-query -W -f='Status=${Status}\nPackage=${Package}\nVersion=${Version}\nArchitecture=${Architecture}\nDepends=${Depends}\nPre-Depends=${Pre-Depends}\nDescription=${binary:Summary}\n' "$p" 2>/dev/null || true
  list="/var/jb/var/lib/dpkg/info/${p}.list"
  if [ -f "$list" ]; then
    echo 'RelevantFiles:'
    grep -Ei '/(TweakInject|MobileSubstrate/DynamicLibraries|PreferenceBundles|PreferenceLoader/Preferences)/|\.dylib$' "$list" 2>/dev/null | head -n 120 || true
  fi
done < "$TMP"

echo '\n===== ROOTFUL / WRONG-ARCH SUSPECTS ====='
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' 2>/dev/null | awk '$3=="iphoneos-arm" || $3=="arm" || $3=="arm64e" {print}' | sort || true

echo '\n===== UNOWNED TWEAK / PREF FILES ====='
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/Library/PreferenceLoader/Preferences; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -type f -print 2>/dev/null | sort | while IFS= read -r f; do
    dpkg-query -S "$f" >/dev/null 2>&1 || echo "$f"
  done
done
find /var/jb/Library/PreferenceBundles -maxdepth 1 -mindepth 1 -type d -print 2>/dev/null | sort | while IFS= read -r f; do
  dpkg-query -S "$f" >/dev/null 2>&1 || echo "$f"
done

echo '\n===== DISABLED / BACKUP INJECTION FILES ====='
find /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries -maxdepth 1 -type f \( -iname '*.disabled' -o -iname '*.bak' -o -iname '*.off' \) -print 2>/dev/null | sort || true

echo '\n===== PREF PLIST -> BUNDLE REFERENCES ====='
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort | while IFS= read -r f; do
  echo "--- $f ---"
  strings "$f" 2>/dev/null | grep -Ei 'bundle|entry|label|title|isController|cell|detail|id|defaults' | head -n 80 || true
done

echo '\n===== INJECTION FILTER SNAPSHOT ====='
for f in /var/jb/usr/lib/TweakInject/*.plist /var/jb/Library/MobileSubstrate/DynamicLibraries/*.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  strings "$f" 2>/dev/null | head -n 80 || true
done

echo '\n===== CURRENT PROCESSES OF INTEREST ====='
ps -A -o pid=,%cpu=,comm= 2>/dev/null | grep -Ei 'SpringBoard|Preferences|Sileo|Zebra|Dopamine|ellekit|backboardd' | head -n 80 || true

rm -f "$TMP"
echo '=== END IPHONE ROOTLESS TWEAK AUDIT ==='
