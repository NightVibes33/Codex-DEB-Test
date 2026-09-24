#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== FAST TWEAK AUDIT V3 ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'safe1='; launchctl getenv _MSSafeMode 2>/dev/null || true
printf 'safe2='; launchctl getenv _SafeMode 2>/dev/null || true
ps ax 2>/dev/null | grep '[S]pringBoard' || true

echo
echo '=== CIRCLEAPPS PREFS ==='
PREF=/var/mobile/Library/Preferences/com.sugiuta.circleapps15.plist
if [ -f "$PREF" ]; then
  ls -lT "$PREF" 2>/dev/null || true
  plutil -p "$PREF" 2>/dev/null || true
else
  echo 'circleapps_pref=missing'
fi
echo '--- defaults ---'
defaults read com.sugiuta.circleapps15 2>/dev/null || true

echo
echo '=== APP ENUMERATION TOOL ==='
if command -v uicache >/dev/null 2>&1; then
  echo "uicache=$(command -v uicache)"
  uicache -l 2>/dev/null | head -n 600 || true
else
  echo 'uicache=missing'
fi

echo
echo '=== CHOICY RULES ==='
for f in /var/mobile/Library/Preferences/com.opa334.choicy.plist /var/mobile/Library/Preferences/com.opa334.choicyprefs.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || true
done

echo
echo '=== DISABLED PAYLOADS ==='
find /var/jb/usr/lib/TweakInject -maxdepth 1 -type f -name '*.disabled' -print 2>/dev/null | sort || true

echo
echo '=== BAD FILTER PLISTS ==='
for p in /var/jb/usr/lib/TweakInject/*.plist; do
  [ -f "$p" ] || continue
  plutil -lint "$p" >/dev/null 2>&1 || echo "bad_plist=$p"
done

echo
echo '=== SPRINGBOARD FILTER FILES ==='
for p in /var/jb/usr/lib/TweakInject/*.plist; do
  [ -f "$p" ] || continue
  if strings "$p" 2>/dev/null | grep -Eqi 'com\.apple\.springboard|SpringBoard'; then
    n="${p##*/}"; n="${n%.plist}"
    echo "$n"
  fi
done | sort

echo
echo '=== PACKAGE HEALTH ==='
dpkg --audit 2>&1 || true
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null  | grep -Ei 'circleapps|choicy|cephei|altlist|ellekit|substrate|rocketbootstrap|applist|snowboard|crane|cylinder|dynamicstage|little16|interactive|speedster|waktos|stella|sonus|explosive|fivecolumns|exsto|tweakhub|sentinel'  | sort || true

echo
echo '=== TWEAK FILE PERMISSIONS / ZERO-SIZE ==='
find /var/jb/usr/lib/TweakInject -maxdepth 1 -type f \( -name '*.dylib' -o -name '*.plist' \) -print 2>/dev/null | while IFS= read -r f; do
  sz="$(stat -f '%z' "$f" 2>/dev/null)"
  [ "$sz" = "0" ] && echo "zero_size=$f"
  [ -r "$f" ] || echo "unreadable=$f"
done

echo 'FAST_TWEAK_AUDIT_V3_COMPLETE=1'
exit 0
