#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== IPHONE SPRINGBOARD SAFE-MODE FORENSICS ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'uname='; uname -a 2>/dev/null || true
printf 'uptime='; uptime 2>/dev/null || true

echo
echo '=== JAILBREAK / INJECTION RUNTIME ==='
for f in /var/jb/.installed_dopamine /var/jb/.procursus_strapped /var/jb/usr/lib/ellekit/libinjector.dylib /var/jb/usr/lib/ellekit/pspawn.dylib /var/jb/usr/lib/TweakLoader.dylib /var/jb/usr/lib/TweakInject.dylib; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  ls -la "$f" 2>/dev/null || true
  readlink "$f" 2>/dev/null || true
done
echo '--- injection framework packages ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version}\n' 2>/dev/null | grep -Ei 'ellekit|substrate|substitute|libhooker|safe.?mode|dopamine' || true

echo
echo '=== SPRINGBOARD / BACKBOARDD PROCESS STATE ==='
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true
SBPID="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
BBPID="$(ps ax 2>/dev/null | awk '/[b]ackboardd/{print $1; exit}')"
[ -n "$SBPID" ] && { echo "--- SpringBoard env pid=$SBPID ---"; ps eww -p "$SBPID" 2>/dev/null | head -c 16000; echo; }
[ -n "$BBPID" ] && { echo "--- backboardd env pid=$BBPID ---"; ps eww -p "$BBPID" 2>/dev/null | head -c 16000; echo; }

echo
echo '=== SAFE-MODE MARKERS / PREFS ==='
find /var/mobile/Library/Preferences /var/jb/var/mobile/Library/Preferences -maxdepth 1 -type f 2>/dev/null \
  | grep -Ei 'substrate|ellekit|substitute|safemode|safe.?mode|crash' | head -n 120 || true
for f in \
  /var/mobile/Library/Preferences/com.saurik.substrate.safemode.plist \
  /var/mobile/Library/Preferences/com.saurik.substrate.plist \
  /var/mobile/Library/Preferences/com.opa334.ellekit.plist \
  /var/mobile/Library/Preferences/com.ellekit.plist; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  plutil -p "$f" 2>/dev/null || cat "$f" 2>/dev/null || true
done

echo
echo '=== INSTALLED TWEAK PAYLOADS + OWNERS ==='
TMP_TWEAKS="/tmp/safemode-tweaks.$$"
: > "$TMP_TWEAKS"
for d in \
  /var/jb/Library/MobileSubstrate/DynamicLibraries \
  /Library/MobileSubstrate/DynamicLibraries \
  /var/jb/usr/lib/TweakInject \
  /usr/lib/TweakInject; do
  [ -d "$d" ] || continue
  echo "TWEAK_DIR=$d"
  find "$d" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sort | while IFS= read -r f; do
    case "$f" in
      *.dylib|*.dylib.disabled|*.disabled|*.plist)
        printf '%s\n' "$f" >> "$TMP_TWEAKS"
        ;;
    esac
  done
done
sort -u "$TMP_TWEAKS" -o "$TMP_TWEAKS" 2>/dev/null || true
while IFS= read -r f; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  echo "--- PAYLOAD $f ---"
  ls -lT "$f" 2>/dev/null || ls -l "$f" 2>/dev/null || true
  echo "owner=$(dpkg-query -S "$f" 2>/dev/null | head -n 1)"
  case "$f" in
    *.plist)
      echo 'filter:'
      plutil -p "$f" 2>/dev/null | head -n 120 || strings "$f" 2>/dev/null | head -n 120 || true
      ;;
  esac
done < "$TMP_TWEAKS"

echo
echo '=== TWEAK PACKAGE INVENTORY ==='
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${Status}\n' 2>/dev/null \
  | grep -Ei 'tweak|substrate|ellekit|theme|springboard|snowboard|velvet|lynx|atria|choicy|shuffle|nicebar|floatingdock|fiveicon|dock|ccsupport|powerselector|ampere|aim|designer|lock|statusbar|controlcenter|keyboard|homebar|gesture|animation|sim|speedy|gif2ani' \
  | sort | head -n 500 || true

echo
echo '=== RECENT PACKAGE CHANGES ==='
for log in /var/jb/var/log/dpkg.log /var/log/dpkg.log /var/jb/var/log/apt/history.log /var/log/apt/history.log /var/jb/var/log/apt/term.log /var/log/apt/term.log; do
  [ -f "$log" ] || continue
  echo "--- $log (tail) ---"
  tail -n 220 "$log" 2>/dev/null || true
done

echo
echo '=== RECENT SPRINGBOARD / BACKBOARDD CRASH FILES ==='
TMP_CRASH="/tmp/safemode-crashes.$$"
: > "$TMP_CRASH"
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter /Library/Logs/CrashReporter /private/var/Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 2 -type f \( \
    -iname 'SpringBoard-*.ips' -o -iname 'SpringBoard-*.crash' -o \
    -iname 'backboardd-*.ips' -o -iname 'backboardd-*.crash' -o \
    -iname '*SafeMode*.ips' -o -iname '*SafeMode*.crash' -o \
    -iname 'JetsamEvent-*.ips' \
  \) -print 2>/dev/null
done | sort -u > "$TMP_CRASH"
ls -lt $(cat "$TMP_CRASH" 2>/dev/null) 2>/dev/null | head -n 40 || true

echo
echo '=== LATEST CRASH CONTENT / INJECTED IMAGES ==='
COUNT=0
for f in $(ls -t $(cat "$TMP_CRASH" 2>/dev/null) 2>/dev/null | head -n 8); do
  [ -f "$f" ] || continue
  COUNT=$((COUNT+1))
  echo "===== CRASH_$COUNT=$f ====="
  echo '--- header / exception / termination ---'
  head -n 35 "$f" 2>/dev/null || true
  grep -a -Ei 'exception|termination|reason|signal|faulting|triggered|culprit|safe.?mode|watchdog|jetsam|namespace' "$f" 2>/dev/null | head -n 100 || true
  echo '--- tweak / jailbreak image references ---'
  strings "$f" 2>/dev/null \
    | grep -Ei '/var/jb|MobileSubstrate|TweakInject|DynamicLibraries|ellekit|substrate|substitute|\.dylib' \
    | sed -E 's/[[:space:]]+/ /g' \
    | head -n 260 || true
done
echo "crash_files_examined=$COUNT"

echo
echo '=== CRASH FREQUENCY LAST 24H ==='
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  echo "ROOT=$root"
  find "$root" -maxdepth 1 -type f -mmin -1440 2>/dev/null \
    | sed 's#.*/##' \
    | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}.*##' \
    | sort | uniq -c | sort -nr | head -n 80 || true
done

echo
echo '=== UNIFIED LOG SAFE-MODE / SPRINGBOARD SIGNALS (BEST EFFORT) ==='
if command -v log >/dev/null 2>&1; then
  log show --last 45m --style compact 2>/dev/null \
    | grep -Ei 'SpringBoard|backboardd|safe.?mode|substrate|ellekit|tweak|dyld|abort|crash' \
    | tail -n 320 || true
fi

echo
echo '=== DYLIB ARCH / DEPENDENCY CHECK ==='
while IFS= read -r f; do
  case "$f" in
    *.dylib)
      [ -f "$f" ] || continue
      echo "--- $f ---"
      file "$f" 2>/dev/null || true
      otool -L "$f" 2>/dev/null | head -n 80 || true
      ;;
  esac
done < "$TMP_TWEAKS"

rm -f "$TMP_TWEAKS" "$TMP_CRASH"
echo 'IPHONE_SAFE_MODE_FORENSICS_COMPLETE=1'
exit 0
