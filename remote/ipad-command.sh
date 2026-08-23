#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile
APP=/var/jb/Applications/Zebra.app
BIN="$APP/Zebra"

echo '=== Zebra focused launch-hang profile ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true

echo '--- installed package ---'
dpkg-query -W -f='status=${Status}\npackage=${Package}\nversion=${Version}\narch=${Architecture}\n' xyz.willy.zebra 2>/dev/null || true
apt-cache policy xyz.willy.zebra 2>/dev/null | head -n 30 || true

echo '--- installed files / hashes ---'
ls -l "$BIN" "$APP/Info.plist" 2>/dev/null || true
if command -v sha256sum >/dev/null 2>&1; then sha256sum "$BIN" 2>/dev/null || true; fi
if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$BIN" 2>/dev/null || true; fi

echo '--- executable metadata ---'
file "$BIN" 2>/dev/null || true
if command -v otool >/dev/null 2>&1; then otool -hv "$BIN" 2>/dev/null | head -n 20 || true; fi

echo '--- entitlements ---'
if command -v ldid >/dev/null 2>&1; then
  ldid -e "$BIN" 2>&1 || true
else
  echo 'ldid=missing'
fi

echo '--- plist version ---'
if command -v plutil >/dev/null 2>&1; then
  plutil -p "$APP/Info.plist" 2>/dev/null | grep -Ei 'CFBundleIdentifier|CFBundleVersion|CFBundleShortVersionString|MinimumOSVersion|CFBundleExecutable' || true
fi

echo '--- launch Zebra with injection suppressed ---'
killall -9 Zebra 2>/dev/null || true
launchctl setenv DISABLE_TWEAKS 1 2>/dev/null || true
launchctl setenv _MSSafeMode 1 2>/dev/null || true
sudo -u mobile launchctl setenv DISABLE_TWEAKS 1 2>/dev/null || true
sudo -u mobile launchctl setenv _MSSafeMode 1 2>/dev/null || true
sudo -u mobile uiopen 'zbra://' >/tmp/zebra-focus-open.txt 2>&1 || true
cat /tmp/zebra-focus-open.txt 2>/dev/null || true
sleep 4
PID="$(ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}')"
echo "pid_t4=${PID:-absent}"
if [ -n "$PID" ]; then
  ps -p "$PID" -o pid,ppid,state,%cpu,%mem,time,command 2>/dev/null || true
  echo '--- live sample ---'
  if command -v sample >/dev/null 2>&1; then
    sample "$PID" 3 1 2>&1 | head -n 260 || true
  else
    echo 'sample=missing'
  fi
fi
sleep 10
PID2="$(ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}')"
echo "pid_t14=${PID2:-absent}"
if [ -n "$PID2" ]; then ps -p "$PID2" -o pid,ppid,state,%cpu,%mem,time,command 2>/dev/null || true; fi
sleep 12
PID3="$(ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}')"
echo "pid_t26=${PID3:-absent}"

echo '--- newest Zebra watchdog summary ---'
CR=/var/mobile/Library/Logs/CrashReporter
LATEST="$(find "$CR" -maxdepth 1 -type f -iname 'Zebra-*.ips' -print 2>/dev/null | while IFS= read -r f; do printf '%s %s\n' "$(stat -f '%m' "$f" 2>/dev/null || echo 0)" "$f"; done | sort -nr | head -n1 | cut -d' ' -f2-)"
echo "report=${LATEST:-none}"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  grep -E 'timestamp|procName|procPath|termination|Watchdog|Elapsed application CPU|process-launch' "$LATEST" 2>/dev/null | head -n 35 || true
fi

launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
launchctl unsetenv _MSSafeMode 2>/dev/null || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>/dev/null || true

echo 'zebra_focused_profile_complete=true'
exit 0
