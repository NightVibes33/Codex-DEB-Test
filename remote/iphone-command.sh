#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }
INFO=/var/jb/var/lib/dpkg/info
TI=/var/jb/usr/lib/TweakInject

echo '=== IPHONE TWEAK / SETTINGS ONE-PASS DIAGNOSTIC ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"

section 'CORE ROOTLESS STACK'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${db:Status-Abbrev}\t${Description}\n' ellekit preferenceloader com.rpetrich.rocketbootstrap xyz.cypwn.applist 2>/dev/null
ls -ld /var/jb "$TI" /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences 2>/dev/null

section 'ALL INSTALLED TWEAK CANDIDATES'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Section}\t${db:Status-Abbrev}\t${Description}\n' 2>/dev/null \
 | grep -Ei 'tweak|springboard|appsync|rocketbootstrap|applist|revenuecat|filza|gboard|icleaner|startup|autolaunch|memoryreset|troller|afc2|arthur|maintenanced' \
 | head -n 400

section 'ONE-PASS DPKG FILE INDEX FOR TWEAKS / SETTINGS'
grep -H -E '/var/jb/(Library/MobileSubstrate/DynamicLibraries/|usr/lib/TweakInject/|Library/PreferenceBundles/|Library/PreferenceLoader/Preferences/)' "$INFO"/*.list 2>/dev/null \
 | sed "s#^$INFO/##" \
 | head -n 1000

section 'ACTUAL TWEAK FILES'
find "$TI" -maxdepth 1 -type f \( -name '*.dylib' -o -name '*.plist' \) -print 2>/dev/null | sort

section 'ACTUAL SETTINGS ENTRIES ON DISK'
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort
find /var/jb/Library/PreferenceBundles -maxdepth 1 -type d -name '*.bundle' -print 2>/dev/null | sort

section 'PREFERENCELOADER FILTER'
P="$TI/PreferenceLoader.plist"
if [ -f "$P" ]; then
  plutil -convert xml1 -o - "$P" 2>/dev/null | head -n 120
fi

section 'ALL TWEAK FILTER TARGETS'
for p in "$TI"/*.plist; do
  [ -f "$p" ] || continue
  echo "FILTER=$(basename "$p")"
  plutil -convert xml1 -o - "$p" 2>/dev/null | grep -E '<key>|<string>' | head -n 60
  echo
done

section 'ELLEKIT LOADER INTEGRITY'
for p in /var/jb/usr/lib/ellekit/libinjector.dylib /var/jb/usr/lib/ellekit/pspawn.dylib /var/jb/usr/libexec/ellekit/loader /var/jb/usr/lib/TweakInject.dylib /var/jb/usr/lib/TweakLoader.dylib /var/jb/etc/rc.d/ellekit-loader; do
  if [ -e "$p" ]; then ls -l "$p" 2>/dev/null; else echo "MISSING $p"; fi
done

section 'SAFE MODE / DISABLED MARKERS'
find /var/jb /var/mobile -maxdepth 4 \( -name '*.disabled' -o -iname '*safemode*' -o -iname '*tweak*disable*' \) -print 2>/dev/null | head -n 100

section 'SPRINGBOARD / SETTINGS STATE'
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | grep -Ei 'SpringBoard|Preferences' | head -n 50
SBPID="$(pgrep -x SpringBoard 2>/dev/null | head -n1)"
echo "SpringBoardPID=$SBPID"
if [ -n "$SBPID" ] && command -v lsof >/dev/null 2>&1; then
  echo 'LOADED_JB_LIBRARIES:'
  lsof -p "$SBPID" 2>/dev/null | grep -E '/var/jb|TweakInject|ellekit|substrate' | head -n 250
else
  echo 'lsof unavailable; direct loaded-dylib enumeration unavailable'
fi

section 'RECENT SETTINGS / SPRINGBOARD CRASHES'
CR=/var/mobile/Library/Logs/CrashReporter
find "$CR" -maxdepth 2 -type f \( -iname 'Preferences*.ips' -o -iname 'SpringBoard*.ips' \) -print 2>/dev/null | sort | tail -n 20

section 'DPKG AUDIT FIRST LINES'
dpkg --audit 2>&1 | head -n 20

echo '=== END ONE-PASS TWEAK DIAGNOSTIC ==='
