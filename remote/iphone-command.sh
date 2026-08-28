#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }
TI=/var/jb/usr/lib/TweakInject
INFO=/var/jb/var/lib/dpkg/info

echo '=== IPHONE TWEAK RUNTIME INJECTION DIAGNOSTIC ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"

section 'PROCESS STATE'
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | grep -Ei 'SpringBoard|Preferences|TweakSettings|Sileo|Zebra' | head -n 80

section 'JAILBREAK / INJECTION SERVICES'
launchctl list 2>/dev/null | grep -Ei 'ellekit|rocket|substrate|substitute|tweak|preference|dopamine' | head -n 120

section 'FILTER CONTENTS VIA STRINGS'
for p in PreferenceLoader.plist appstoretroller.plist 0Hello3Q.plist AutoRevenueCat.plist mmaintenanced_hook.plist GboardAll.plist AppList.plist; do
  f="$TI/$p"
  echo "FILTER=$f"
  if [ -f "$f" ]; then strings "$f" 2>/dev/null | head -n 100; else echo MISSING; fi
  echo
done

section 'PREFERENCELOADER SETTINGS ENTRY'
for f in /var/jb/Library/PreferenceLoader/Preferences/*.plist; do
  [ -f "$f" ] || continue
  echo "ENTRY=$f"
  strings "$f" 2>/dev/null | head -n 120
  echo
done

section 'PREFERENCE BUNDLE METADATA'
for b in /var/jb/Library/PreferenceBundles/*.bundle; do
  [ -d "$b" ] || continue
  echo "BUNDLE=$b"
  strings "$b/Info.plist" 2>/dev/null | head -n 100
  echo
done

section 'TWEAKSETTINGS PACKAGE FILES'
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${db:Status-Abbrev}\t${Description}\n' xyz.cypwn.tweaksettings 2>/dev/null
dpkg-query -L xyz.cypwn.tweaksettings 2>/dev/null | head -n 250

section 'SYSTEM TWEAK PACKAGE SCRIPTS'
for pkg in xyz.cypwn.startupoptimizations xyz.cypwn.stopautolaunchapps xyz.cypwn.systemmemoryresetfix; do
  echo "PACKAGE=$pkg"
  dpkg-query -W -f='version=${Version}\narch=${Architecture}\nstatus=${db:Status-Abbrev}\ndescription=${Description}\n' "$pkg" 2>/dev/null
  echo 'FILES:'
  dpkg-query -L "$pkg" 2>/dev/null | head -n 160
  for suffix in preinst postinst prerm postrm; do
    s="$INFO/$pkg.$suffix"
    if [ -f "$s" ]; then
      echo "SCRIPT=$s"
      sed -n '1,180p' "$s" 2>/dev/null
    fi
  done
  echo
done

section 'SHSHD LAUNCH DAEMON / OWNER'
find /var/jb/Library/LaunchDaemons /var/jb/Library/Daemons /var/jb/etc -maxdepth 3 -type f -iname '*shsh*' -print 2>/dev/null | head -n 100
launchctl list 2>/dev/null | grep -Ei 'shsh|diatr' | head -n 50
for lf in "$INFO"/*.list; do
  [ -f "$lf" ] || continue
  if grep -Eqi 'shshd|us\.diatr' "$lf" 2>/dev/null; then
    echo "OWNER_MANIFEST=$lf"
    grep -Ei 'shshd|us\.diatr' "$lf" 2>/dev/null | head -n 80
  fi
done

section 'ELLEKIT / INJECTION LOG SIGNALS'
for root in /var/mobile/Library/Logs /var/jb/var/log /var/log; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 3 -type f 2>/dev/null | grep -Ei 'ellekit|inject|substrate|preference' | head -n 80
done

section 'RECENT SPRINGBOARD / SETTINGS REPORTS'
CR=/var/mobile/Library/Logs/CrashReporter
find "$CR" -maxdepth 2 -type f \( -iname 'SpringBoard*.ips' -o -iname 'Preferences*.ips' \) -print 2>/dev/null | sort | tail -n 30

section 'DYLIB LINK DEPENDENCY STRINGS'
for f in "$TI"/*.dylib; do
  [ -f "$f" ] || continue
  echo "DYLIB=$(basename "$f")"
  strings "$f" 2>/dev/null | grep -E '/var/jb|MobileSubstrate|Substrate|ElleKit|libhooker|PreferenceLoader|RocketBootstrap' | head -n 40
  echo
done

section 'CURRENT TWEAK FILE PERMISSIONS'
ls -la "$TI" 2>/dev/null | head -n 120

echo '=== END RUNTIME INJECTION DIAGNOSTIC ==='
