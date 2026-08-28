#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo '=== IPHONE THEME TWEAK / SETTINGS PANE AUDIT ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== CORE JAILBREAK PACKAGES =====\n'
for pkg in preferenceloader ellekit com.rpetrich.rocketbootstrap xyz.cypwn.applist xyz.cypwn.tweaksettings; do
  dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\tDepends=${Depends}\n' "$pkg" 2>/dev/null || true
done

printf '\n===== INSTALLED PACKAGES LIKELY RELATED TO THEMING/UI =====\n'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\t${Description}\n' 2>/dev/null \
 | grep -Ei 'theme|snowboard|anemone|icon|dock|springboard|wallpaper|widget|status bar|control center|lockscreen|homescreen|ui tweak|customi|appearance|aesthetic|font|badge|folder|designer|atria|velvet|solstice|felicity|viola|miso|echo|lynx|jade|nicebar|dress|color' \
 | head -n 250 || true

printf '\n===== ALL TWEAKINJECT FILES + PACKAGE OWNERS =====\n'
TI=/var/jb/usr/lib/TweakInject
if [ -d "$TI" ]; then
  for f in "$TI"/*; do
    [ -e "$f" ] || continue
    case "$f" in *.dylib|*.plist)
      echo "FILE=$f"
      dpkg-query -S "$f" 2>/dev/null || dpkg-query -S "${f#/var/jb}" 2>/dev/null || echo 'owner=UNKNOWN'
      ;;
    esac
  done
else
  echo 'TweakInject=MISSING'
fi

printf '\n===== ROOTLESS SETTINGS FILES =====\n'
for d in /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences; do
  echo "DIR=$d"
  if [ -d "$d" ]; then
    find "$d" -maxdepth 3 -mindepth 1 -print 2>/dev/null | sort | head -n 400
  else
    echo MISSING
  fi
done

printf '\n===== SEARCH FOR PREF FILES OUTSIDE EXPECTED ROOTLESS PATH =====\n'
for d in /Library/PreferenceBundles /Library/PreferenceLoader/Preferences /usr/lib/TweakInject; do
  echo "DIR=$d"
  if [ -d "$d" ]; then
    find "$d" -maxdepth 3 -mindepth 1 -print 2>/dev/null | sort | head -n 250
  else
    echo MISSING
  fi
done

printf '\n===== PACKAGES WHOSE MANIFESTS CLAIM SETTINGS FILES =====\n'
for list in /var/jb/var/lib/dpkg/info/*.list; do
  [ -f "$list" ] || continue
  hits=$(grep -Ei 'PreferenceBundles|PreferenceLoader/Preferences|prefs\.bundle|preferences.*\.plist' "$list" 2>/dev/null)
  [ -n "$hits" ] || continue
  pkg=$(basename "$list" .list)
  meta=$(dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\tDepends=${Depends}' "$pkg" 2>/dev/null)
  echo "PKG_META=$meta"
  printf '%s\n' "$hits" | head -n 60
  echo '-- existence --'
  printf '%s\n' "$hits" | head -n 60 | while IFS= read -r p; do
    if [ -e "$p" ]; then echo "EXISTS $p"; else echo "MISSING $p"; fi
  done
  echo
 done

printf '\n===== PACKAGE ARCHITECTURE COUNTS =====\n'
dpkg-query -W -f='${Architecture}\n' 2>/dev/null | sort | uniq -c | sort -nr || true

echo '-- rootful-looking iphoneos-arm packages --'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\n' 2>/dev/null | awk -F '\t' '$3=="iphoneos-arm" {print}' | head -n 250 || true

printf '\n===== DPKG AUDIT / BROKEN DEPENDENCIES =====\n'
dpkg --audit 2>&1 || true
if command -v apt-get >/dev/null 2>&1; then apt-get check 2>&1 || true; fi

printf '\n===== THEMES DIRECTORIES =====\n'
for d in /var/jb/Library/Themes /Library/Themes /var/mobile/Library/SnowBoard /var/mobile/Library/Designer; do
  echo "DIR=$d"
  if [ -d "$d" ]; then find "$d" -maxdepth 2 -mindepth 1 -print 2>/dev/null | head -n 250; else echo MISSING; fi
done

printf '\n===== SETTINGS / SPRINGBOARD STATE =====\n'
ps -A -o pid=,ppid=,%cpu=,%mem=,comm= 2>/dev/null | grep -Ei 'Preferences|SpringBoard' || true
launchctl list 2>/dev/null | grep -Ei 'ellekit|rocketbootstrap|dopamine' || true

echo '=== END IPHONE THEME TWEAK / SETTINGS PANE AUDIT ==='
