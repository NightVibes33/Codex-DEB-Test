#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }
INFO=/var/jb/var/lib/dpkg/info
TI=/var/jb/usr/lib/TweakInject

echo '=== IPHONE TWEAK PACKAGE / SETTINGS MAP ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"

section 'CORE STATUS'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${db:Status-Abbrev}\t${Description}\n' ellekit preferenceloader com.rpetrich.rocketbootstrap xyz.cypwn.applist 2>/dev/null

section 'TWEAK FILE -> PACKAGE OWNER VIA DPKG .list'
for f in "$TI"/*.dylib "$TI"/*.plist; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  alias="/var/jb/Library/MobileSubstrate/DynamicLibraries/$base"
  echo "FILE=$base"
  owner=''
  for lf in "$INFO"/*.list; do
    [ -f "$lf" ] || continue
    if grep -Fxq "$alias" "$lf" 2>/dev/null || grep -Fxq "$f" "$lf" 2>/dev/null; then
      pkg="$(basename "$lf" .list)"
      echo "OWNER=$pkg"
      dpkg-query -W -f='VERSION=${Version}\nARCH=${Architecture}\nSTATUS=${db:Status-Abbrev}\nDESCRIPTION=${Description}\n' "$pkg" 2>/dev/null | head -n 8
      owner="$pkg"
      break
    fi
  done
  [ -n "$owner" ] || echo 'OWNER=NO_DPKG_LIST_MATCH'
done

section 'INSTALLED PACKAGES THAT SHIP TWEAKS OR PREFERENCE PANES'
for lf in "$INFO"/*.list; do
  [ -f "$lf" ] || continue
  if grep -Eq '/(MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/.*\.(dylib|plist)$|/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$lf" 2>/dev/null; then
    pkg="$(basename "$lf" .list)"
    echo "PACKAGE=$pkg"
    dpkg-query -W -f='VERSION=${Version}\nARCH=${Architecture}\nSTATUS=${db:Status-Abbrev}\nDESCRIPTION=${Description}\n' "$pkg" 2>/dev/null | head -n 8
    echo 'FILES:'
    grep -E '/(MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/|/Library/PreferenceBundles/|/Library/PreferenceLoader/Preferences/' "$lf" 2>/dev/null | head -n 100
    echo
  fi
done

section 'ALL SETTINGS ENTRIES'
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort
for p in /var/jb/Library/PreferenceLoader/Preferences/*.plist; do
  [ -f "$p" ] || continue
  echo "PREF_ENTRY=$p"
  plutil -convert xml1 -o - "$p" 2>/dev/null | head -n 120 || cat "$p" 2>/dev/null | head -n 120
  echo
done

section 'ALL PREFERENCE BUNDLES'
for b in /var/jb/Library/PreferenceBundles/*.bundle; do
  [ -d "$b" ] || continue
  echo "BUNDLE=$b"
  info="$b/Info.plist"
  [ -f "$info" ] && plutil -convert xml1 -o - "$info" 2>/dev/null | head -n 100
  echo
done

section 'TWEAK FILTER CONTENTS'
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  echo "FILTER=$(basename "$p")"
  if command -v plutil >/dev/null 2>&1; then
    plutil -convert xml1 -o - "$p" 2>/dev/null | head -n 120
  else
    strings "$p" 2>/dev/null | head -n 80
  fi
  echo
done

section 'DISABLED / SAFE MODE MARKERS'
find /var/jb /var/mobile -maxdepth 5 \( -name '*.disabled' -o -iname '*safemode*' -o -iname '*tweak*disable*' \) -print 2>/dev/null | head -n 200

section 'ELLEKIT LOADER FILES'
ls -la /var/jb/usr/lib/ellekit /var/jb/usr/libexec/ellekit /var/jb/etc/rc.d/ellekit-loader /var/jb/usr/lib/TweakInject.dylib /var/jb/usr/lib/TweakLoader.dylib 2>/dev/null

section 'SPRINGBOARD LOADED TWEAKS IF LSOF AVAILABLE'
SBPID="$(pgrep -x SpringBoard 2>/dev/null | head -n1)"
echo "SpringBoardPID=$SBPID"
if [ -n "$SBPID" ] && command -v lsof >/dev/null 2>&1; then
  lsof -p "$SBPID" 2>/dev/null | grep -E '/var/jb|TweakInject|ellekit|substrate' | head -n 250
else
  echo 'lsof unavailable or SpringBoard PID missing'
fi

section 'PACKAGE DB AUDIT'
dpkg --audit 2>&1 | head -n 200

echo '=== END TWEAK PACKAGE / SETTINGS MAP ==='
