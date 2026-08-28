#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }

echo '=== IPHONE TWEAK INJECTION / PREFERENCELOADER DIAGNOSTIC ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "uname=$(uname -a 2>/dev/null)"

section 'BOOTSTRAP ROOTS / MARKERS'
for p in /var/jb /var/jb/basebin /var/jb/usr/lib/TweakInject /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences /Library/PreferenceBundles /Library/PreferenceLoader/Preferences; do
  if [ -e "$p" ]; then ls -ld "$p" 2>/dev/null; else echo "MISSING $p"; fi
done
find /var/jb /var/mobile -maxdepth 3 -type f \( -iname '*safe*mode*' -o -name '*.disabled' -o -iname '*tweak*disable*' \) -print 2>/dev/null | head -n 100

section 'CORE TWEAK PACKAGES'
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${db:Status-Abbrev}\t${Description}\n' 2>/dev/null \
    | grep -Ei 'ellekit|preferenceloader|preference|applist|rocketbootstrap|cephei|substrate|substitute|libhooker|tweakinject|safe.?mode' \
    | head -n 200
fi

echo '-- dpkg audit --'
dpkg --audit 2>&1 | head -n 100

section 'PACKAGE DATABASE PATH CHECK'
D=/var/jb/usr/lib/TweakInject
if [ -d "$D" ]; then
  find "$D" -maxdepth 1 -type f -print 2>/dev/null | sort | while IFS= read -r f; do
    rel="${f#/var/jb}"
    echo "file=$f"
    echo "relative=$rel"
    if command -v dpkg-query >/dev/null 2>&1; then
      a="$(dpkg-query -S "$f" 2>/dev/null | head -n 1)"
      b="$(dpkg-query -S "$rel" 2>/dev/null | head -n 1)"
      [ -n "$a" ] && echo "owner_abs=$a" || echo 'owner_abs=NONE'
      [ -n "$b" ] && echo "owner_rootless=$b" || echo 'owner_rootless=NONE'
    fi
  done
fi

section 'PREFERENCELOADER PACKAGE CONTENTS'
if command -v dpkg-query >/dev/null 2>&1; then
  for pkg in $(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -Ei 'preferenceloader|preference.?loader'); do
    echo "PACKAGE=$pkg"
    dpkg-query -W -f='version=${Version}\narch=${Architecture}\nstatus=${db:Status-Abbrev}\ndescription=${Description}\n' "$pkg" 2>/dev/null
    dpkg-query -L "$pkg" 2>/dev/null | head -n 200
  done
fi

section 'ELLEKIT PACKAGE CONTENTS'
if command -v dpkg-query >/dev/null 2>&1; then
  for pkg in $(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -Ei '^ellekit$|ellekit'); do
    echo "PACKAGE=$pkg"
    dpkg-query -W -f='version=${Version}\narch=${Architecture}\nstatus=${db:Status-Abbrev}\ndescription=${Description}\n' "$pkg" 2>/dev/null
    dpkg-query -L "$pkg" 2>/dev/null | head -n 200
  done
fi

section 'PREFERENCE DIRECTORIES'
for d in /var/jb/Library/PreferenceBundles /var/jb/Library/PreferenceLoader/Preferences /Library/PreferenceBundles /Library/PreferenceLoader/Preferences; do
  echo "DIR=$d"
  if [ -d "$d" ]; then
    find "$d" -maxdepth 2 -print 2>/dev/null | sort | head -n 300
  else
    echo MISSING
  fi
done

section 'PREFERENCE BUNDLE EXECUTABLES / OWNERS'
for b in /var/jb/Library/PreferenceBundles/*.bundle; do
  [ -d "$b" ] || continue
  echo "BUNDLE=$b"
  info="$b/Info.plist"
  exe=''
  if [ -f "$info" ]; then
    if command -v plutil >/dev/null 2>&1; then
      plutil -p "$info" 2>/dev/null | head -n 80
    fi
    exe="$(defaults read "$info" CFBundleExecutable 2>/dev/null | tail -n 1)"
    [ -n "$exe" ] || exe="$(basename "$b" .bundle)"
  fi
  [ -n "$exe" ] && [ -e "$b/$exe" ] && {
    echo "EXEC=$b/$exe"
    command -v file >/dev/null 2>&1 && file "$b/$exe" 2>/dev/null
  }
  rel="${b#/var/jb}"
  o="$(dpkg-query -S "$rel" 2>/dev/null | head -n 1)"
  [ -n "$o" ] && echo "owner=$o" || echo 'owner=NONE'
done

section 'TWEAK DYLIB ARCHITECTURES / FILTERS'
for f in /var/jb/usr/lib/TweakInject/*.dylib; do
  [ -f "$f" ] || continue
  echo "DYLIB=$f"
  command -v file >/dev/null 2>&1 && file "$f" 2>/dev/null
  p="${f%.dylib}.plist"
  if [ -f "$p" ]; then
    echo "FILTER=$p"
    if command -v plutil >/dev/null 2>&1; then
      plutil -p "$p" 2>/dev/null | head -n 100
    fi
    strings "$p" 2>/dev/null | head -n 80
  fi
done

section 'SETTINGS / SPRINGBOARD PROCESSES'
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | grep -Ei 'Preferences|SpringBoard|ellekit|substrate|substitute|libhooker' | head -n 100

section 'ELLEKIT / PREFERENCELOADER FILE SEARCH'
find /var/jb -maxdepth 6 \( -iname '*ElleKit*' -o -iname '*PreferenceLoader*' \) -print 2>/dev/null | sort | head -n 300

section 'DYNAMIC LIBRARY PATHS / SYMLINKS'
for d in /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/usr/lib/TweakInject; do
  echo "DIR=$d"
  ls -la "$d" 2>/dev/null | head -n 250
done

section 'RELEVANT DPKG STATUS STANZAS'
STATUS=/var/jb/var/lib/dpkg/status
if [ -f "$STATUS" ]; then
  grep -in -B 4 -A 16 -E 'Package: (ellekit|.*preferenceloader|com\.rpetrich\.rocketbootstrap|applist)' "$STATUS" 2>/dev/null | head -n 400
fi

section 'RECENT TWEAK / SETTINGS CRASH REPORTS'
CR=/var/mobile/Library/Logs/CrashReporter
find "$CR" -maxdepth 2 -type f \( -iname 'Preferences*.ips' -o -iname 'SpringBoard*.ips' -o -iname '*ElleKit*.ips' \) -print 2>/dev/null | sort | tail -n 40
for f in $(find "$CR" -maxdepth 2 -type f \( -iname 'Preferences*.ips' -o -iname 'SpringBoard*.ips' \) -print 2>/dev/null | sort | tail -n 3); do
  echo "REPORT=$f"
  grep -E 'Exception Type:|Termination Reason:|Triggered by Thread:|Dyld Error|Library not loaded|Abort Cause|Crashed Thread|Last Exception Backtrace' "$f" 2>/dev/null | head -n 80
done

section 'LAUNCHCTL JAILBREAK SERVICES'
launchctl list 2>/dev/null | grep -Ev '^PID|com\.apple\.' | head -n 200

echo '=== END TWEAK DIAGNOSTIC ==='
