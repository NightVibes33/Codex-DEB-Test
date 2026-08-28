#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo '=== IPHONE ROOTLESS TWEAK OWNERSHIP AUDIT ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

echo '\n===== CORE STACK ====='
dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\n' 2>/dev/null | grep -Ei 'ellekit|preferenceloader|substrate|substitute|libhooker|snowboard|cephei|applist|rocketbootstrap' || true
apt-get check 2>&1 || true

echo '\n===== INJECTION DIRECTORY LAYOUT ====='
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  echo "--- $d ---"
  ls -la "$d" 2>/dev/null | head -n 160 || true
done

echo '\n===== SYMLINK / OWNER RESOLUTION ====='
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "$f" in *.dylib|*.plist|*.disabled|*.bak|*.off) ;; *) continue ;; esac
    target=$(readlink "$f" 2>/dev/null)
    real=$(readlink -f "$f" 2>/dev/null)
    owner=$(dpkg-query -S "$f" 2>/dev/null | head -n1 | cut -d: -f1)
    realowner=''
    [ -n "$real" ] && realowner=$(dpkg-query -S "$real" 2>/dev/null | head -n1 | cut -d: -f1)
    printf '%s\ttarget=%s\treal=%s\towner=%s\trealowner=%s\n' "$f" "${target:-DIRECT}" "${real:-UNKNOWN}" "${owner:-NONE}" "${realowner:-NONE}"
  done
done

TMP=/tmp/tweak-pkgs.$$
: > "$TMP"
for list in /var/jb/var/lib/dpkg/info/*.list; do
  [ -f "$list" ] || continue
  if grep -Eq '/(Library/MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/.*\.(dylib|plist)$|/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$list" 2>/dev/null; then
    p=${list##*/}
    p=${p%.list}
    echo "$p" >> "$TMP"
  fi
done
sort -u "$TMP" -o "$TMP" 2>/dev/null || true

echo '\n===== ALL PACKAGES THAT SHIP TWEAK/PREF FILES ====='
while IFS= read -r p; do
  [ -n "$p" ] || continue
  list="/var/jb/var/lib/dpkg/info/${p}.list"
  meta=$(dpkg-query -W -f='${Status}|${Package}|${Version}|${Architecture}|${Depends}|${binary:Summary}' "$p" 2>/dev/null)
  echo "--- $meta ---"
  has_inject=no
  has_prefs=no
  grep -Eq '/(Library/MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/.*\.dylib$' "$list" 2>/dev/null && has_inject=yes
  grep -Eq '/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$list" 2>/dev/null && has_prefs=yes
  echo "classification=inject:${has_inject},settings-pane-files:${has_prefs}"
  grep -Ei '/(Library/MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/.*\.(dylib|plist)$|/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$list" 2>/dev/null | head -n 100 || true
done < "$TMP"

echo '\n===== PACKAGES WITH INJECTION BUT NO SETTINGS PANE ====='
while IFS= read -r p; do
  [ -n "$p" ] || continue
  list="/var/jb/var/lib/dpkg/info/${p}.list"
  if grep -Eq '/(Library/MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/.*\.dylib$' "$list" 2>/dev/null && ! grep -Eq '/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$list" 2>/dev/null; then
    dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${binary:Summary}\n' "$p" 2>/dev/null || true
  fi
done < "$TMP"

echo '\n===== PACKAGES THAT SHOULD APPEAR IN SETTINGS ====='
while IFS= read -r p; do
  [ -n "$p" ] || continue
  list="/var/jb/var/lib/dpkg/info/${p}.list"
  if grep -Eq '/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$list" 2>/dev/null; then
    dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${binary:Summary}\n' "$p" 2>/dev/null || true
  fi
done < "$TMP"

echo '\n===== ROOTFUL / WRONG-ARCH INSTALLED PACKAGES ====='
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' 2>/dev/null | while IFS="$(printf '\t')" read -r p v a; do
  case "$a" in iphoneos-arm|arm|arm64e) printf '%s\t%s\t%s\n' "$p" "$v" "$a" ;; esac
done | sort || true

echo '\n===== PREFERENCELOADER CURRENT ENTRIES ====='
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort || true
find /var/jb/Library/PreferenceBundles -maxdepth 1 -mindepth 1 -type d -print 2>/dev/null | sort || true

echo '\n===== DISABLED INJECTION FILES ====='
find /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries -maxdepth 1 \( -type f -o -type l \) \( -iname '*.disabled' -o -iname '*.bak' -o -iname '*.off' \) -print 2>/dev/null | sort || true

echo '\n===== LIVE UI PROCESSES ====='
ps -A -o pid=,%cpu=,comm= 2>/dev/null | grep -Ei 'SpringBoard|Preferences|backboardd' | head -n 40 || true

rm -f "$TMP"
echo '=== END IPHONE ROOTLESS TWEAK OWNERSHIP AUDIT ==='
