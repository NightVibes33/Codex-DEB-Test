#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }
INFO=/var/jb/var/lib/dpkg/info
TI=/var/jb/usr/lib/TweakInject

echo '=== FAST IPHONE TWEAK / SETTINGS DIAGNOSTIC ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"

section 'CORE ROOTLESS STACK'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${db:Status-Abbrev}\t${Description}\n' ellekit preferenceloader com.rpetrich.rocketbootstrap xyz.cypwn.applist 2>/dev/null
ls -ld /var/jb "$TI" /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences 2>/dev/null

section 'INSTALLED TWEAK-RELATED PACKAGES'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Section}\t${db:Status-Abbrev}\t${Description}\n' 2>/dev/null \
 | grep -Ei '\t(Tweaks|Tweak Injection|System)\t|tweak|springboard|appsync|rocketbootstrap|applist|revenuecat|filza|gboard|icleaner|startup|autolaunch|memoryreset|troller' \
 | head -n 300

section 'TWEAK FILE OWNERS - FAST INDEX LOOKUP'
for f in "$TI"/*.dylib "$TI"/*.plist; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  alias="/var/jb/Library/MobileSubstrate/DynamicLibraries/$base"
  hit="$(grep -lFx "$alias" "$INFO"/*.list 2>/dev/null | head -n1)"
  [ -n "$hit" ] || hit="$(grep -lFx "$f" "$INFO"/*.list 2>/dev/null | head -n1)"
  echo "FILE=$base"
  if [ -n "$hit" ]; then
    pkg="$(basename "$hit" .list)"
    echo "OWNER=$pkg"
    dpkg-query -W -f='VERSION=${Version}\nARCH=${Architecture}\nSTATUS=${db:Status-Abbrev}\nDESCRIPTION=${Description}\n' "$pkg" 2>/dev/null | head -n 6
  else
    echo 'OWNER=NO_DPKG_LIST_MATCH'
  fi
done

section 'PACKAGES SHIPPING SETTINGS PANES'
for lf in $(grep -lE '/var/jb/Library/(PreferenceBundles/|PreferenceLoader/Preferences/)' "$INFO"/*.list 2>/dev/null | sort -u); do
  pkg="$(basename "$lf" .list)"
  echo "PACKAGE=$pkg"
  dpkg-query -W -f='VERSION=${Version}\nARCH=${Architecture}\nSTATUS=${db:Status-Abbrev}\nDESCRIPTION=${Description}\n' "$pkg" 2>/dev/null | head -n 6
  grep -E '/var/jb/Library/(PreferenceBundles/|PreferenceLoader/Preferences/)' "$lf" 2>/dev/null | head -n 80
  echo
done

section 'ACTUAL SETTINGS ENTRIES ON DISK'
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort
find /var/jb/Library/PreferenceBundles -maxdepth 1 -type d -name '*.bundle' -print 2>/dev/null | sort

section 'PREFERENCELOADER INJECTION FILTER'
P=/var/jb/usr/lib/TweakInject/PreferenceLoader.plist
if [ -f "$P" ]; then
  plutil -convert xml1 -o - "$P" 2>/dev/null || strings "$P" 2>/dev/null | head -n 80
fi

section 'TWEAK FILTER TARGETS'
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  echo "FILTER=$(basename "$p")"
  plutil -convert xml1 -o - "$p" 2>/dev/null | grep -E '<key>|<string>' | head -n 80
  echo
done

section 'SAFE MODE / DISABLED MARKERS'
find /var/jb /var/mobile -maxdepth 4 \( -name '*.disabled' -o -iname '*safemode*' -o -iname '*tweak*disable*' \) -print 2>/dev/null | head -n 100

section 'ELLEKIT LOADER INTEGRITY'
for p in /var/jb/usr/lib/ellekit/libinjector.dylib /var/jb/usr/lib/ellekit/pspawn.dylib /var/jb/usr/libexec/ellekit/loader /var/jb/usr/lib/TweakInject.dylib /var/jb/usr/lib/TweakLoader.dylib /var/jb/etc/rc.d/ellekit-loader; do
  if [ -e "$p" ]; then ls -l "$p" 2>/dev/null; else echo "MISSING $p"; fi
done

section 'SPRINGBOARD / SETTINGS PROCESS STATE'
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | grep -Ei 'SpringBoard|Preferences' | head -n 50
SBPID="$(pgrep -x SpringBoard 2>/dev/null | head -n1)"
echo "SpringBoardPID=$SBPID"
if [ -n "$SBPID" ] && command -v lsof >/dev/null 2>&1; then
  echo 'LOADED_JB_LIBRARIES:'
  lsof -p "$SBPID" 2>/dev/null | grep -E '/var/jb|TweakInject|ellekit|substrate' | head -n 200
else
  echo 'lsof unavailable; cannot directly enumerate SpringBoard dylibs'
fi

section 'RECENT SETTINGS / SPRINGBOARD CRASH SIGNALS'
CR=/var/mobile/Library/Logs/CrashReporter
find "$CR" -maxdepth 2 -type f \( -iname 'Preferences*.ips' -o -iname 'SpringBoard*.ips' \) -print 2>/dev/null | sort | tail -n 20

section 'DPKG AUDIT SUMMARY'
dpkg --audit 2>&1 | head -n 40

echo '=== END FAST TWEAK DIAGNOSTIC ==='
