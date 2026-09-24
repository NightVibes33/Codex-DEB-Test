#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

echo '=== SAFE MODE FOCUSED LIVE PROBE ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null
printf 'build='; sw_vers -buildVersion 2>/dev/null
SBPID="$(ps ax 2>/dev/null | awk '/[S]pringBoard/{print $1; exit}')"
echo "springboard_pid=$SBPID"
ps ax 2>/dev/null | grep -E '[S]pringBoard|[b]ackboardd' || true

echo
echo '=== AVAILABLE PROCESS-IMAGE TOOLS ==='
for x in vmmap lsof dyld_info jtool jtool2 sample procinfo; do
  p="$(command -v "$x" 2>/dev/null)"
  [ -n "$p" ] && echo "$x=$p" || echo "$x=missing"
done

if [ -n "$SBPID" ]; then
  if command -v vmmap >/dev/null 2>&1; then
    echo '=== SPRINGBOARD VAR/JB IMAGES VIA VMMAP ==='
    vmmap "$SBPID" 2>/dev/null | grep -E '/var/jb|TweakInject|MobileSubstrate|ellekit|\.dylib' | head -n 300 || true
  fi
  if command -v lsof >/dev/null 2>&1; then
    echo '=== SPRINGBOARD VAR/JB FILES VIA LSOF ==='
    lsof -p "$SBPID" 2>/dev/null | grep -E '/var/jb|TweakInject|MobileSubstrate|ellekit|\.dylib' | head -n 300 || true
  fi
fi

echo
echo '=== DEEP SPRINGBOARD CRASH SEARCH ==='
for root in /var/mobile/Library/Logs/CrashReporter /private/var/mobile/Library/Logs/CrashReporter /var/Library/Logs/CrashReporter /Library/Logs/CrashReporter; do
  [ -d "$root" ] || continue
  echo "ROOT=$root"
  find "$root" -maxdepth 5 -type f 2>/dev/null | grep -Ei '/SpringBoard[^/]*(\.ips|\.crash)?$|springboard' | head -n 120 || true
done

echo
echo '=== RECENT SPRINGBOARD UNIFIED LOG SIGNALS ==='
if command -v log >/dev/null 2>&1; then
  log show --last 6h --style compact --predicate 'process == "SpringBoard"' 2>/dev/null \
    | grep -Ei 'safe.?mode|crash|abort|exception|dyld|ellekit|substrate|tweak|inject|terminate|fault' \
    | tail -n 260 || true
else
  echo 'log_command=missing'
fi

echo
echo '=== RECENT / HIGH-RISK TWEAK FILTERS + PACKAGE OWNERS ==='
for n in Misaka15Compat Polyfills Little16 InteractiveSiri CraneSB CraneSupport Speedster DownloadPercent ChoicySB ChoicyMenu DynamicStage Nazuna 0nazuna Cylinder ExplosiveIcons Exsto15 FiveColumnsCC Waktos Stella; do
  found=0
  for base in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries; do
    p="$base/$n.plist"
    d="$base/$n.dylib"
    [ -e "$p" ] || [ -e "$d" ] || continue
    found=1
    echo "===== $n @ $base ====="
    [ -f "$p" ] && { echo 'filter:'; plutil -p "$p" 2>/dev/null || strings "$p" 2>/dev/null | head -n 100; }
    [ -e "$d" ] && ls -lT "$d" 2>/dev/null || true
    rel="${d#/var/jb}"
    echo "dpkg_owner=$(dpkg-query -S "$rel" 2>/dev/null | head -n1)"
    echo "file=$(file "$d" 2>/dev/null)"
  done
  [ "$found" = 1 ] || true
done

echo
echo '=== PACKAGE STATUS MATCHES ==='
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null \
 | grep -Ei 'misaka|polyfill|little16|interactive.?siri|crane|speedster|downloadpercent|choicy|dynamicstage|nazuna|cylinder|explosive|exsto|fivecolumns|waktos|stella' || true

echo
echo '=== ELLEKIT / SAFEMODE FILES ==='
find /var/jb /var/mobile/Library -maxdepth 5 -type f 2>/dev/null \
 | grep -Ei 'ellekit.*(log|safe)|safe.?mode|substrate.*safe|crash.*springboard' \
 | head -n 160 || true

echo 'SAFE_MODE_FOCUSED_PROBE_COMPLETE=1'
exit 0
