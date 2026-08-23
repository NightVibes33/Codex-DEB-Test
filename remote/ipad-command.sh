#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

zpid() { ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}'; }
probe() {
  label="$1"
  pid="$(zpid)"
  echo "${label}_pid=${pid:-absent}"
  if [ -n "$pid" ]; then
    ps -p "$pid" -o pid,ppid,state,%cpu,%mem,time,command 2>/dev/null || true
    if command -v top >/dev/null 2>&1; then top -l 1 -pid "$pid" 2>/dev/null | grep -E 'Zebra|CPU usage|Load Avg' | head -n 8 || true; fi
  fi
}
watch_launch() {
  prefix="$1"
  sleep 5; probe "${prefix}_t5"
  sleep 15; probe "${prefix}_t20"
  sleep 15; probe "${prefix}_t35"
  sleep 15; probe "${prefix}_t50"
  sleep 20; probe "${prefix}_t70"
}

echo '=== Zebra 70-second A/B launch test ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'
dpkg-query -W -f='version=${Version} arch=${Architecture}\n' xyz.willy.zebra 2>/dev/null || true

# Clear leftovers first.
killall -9 Zebra 2>/dev/null || true
launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
launchctl unsetenv _MSSafeMode 2>/dev/null || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>/dev/null || true
sleep 1

echo '--- A: launch with safe-mode environment requested ---'
launchctl setenv DISABLE_TWEAKS 1 2>/dev/null || true
launchctl setenv _MSSafeMode 1 2>/dev/null || true
sudo -u mobile launchctl setenv DISABLE_TWEAKS 1 2>/dev/null || true
sudo -u mobile launchctl setenv _MSSafeMode 1 2>/dev/null || true
sudo -u mobile uiopen 'zbra://' >/tmp/zebra-ab-a.txt 2>&1 || true
cat /tmp/zebra-ab-a.txt 2>/dev/null || true
watch_launch safe

killall -9 Zebra 2>/dev/null || true
launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
launchctl unsetenv _MSSafeMode 2>/dev/null || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>/dev/null || true
sleep 3

echo '--- B: normal launch ---'
sudo -u mobile uiopen 'zbra://' >/tmp/zebra-ab-b.txt 2>&1 || true
cat /tmp/zebra-ab-b.txt 2>/dev/null || true
watch_launch normal

killall -9 Zebra 2>/dev/null || true

echo '--- newest Zebra reports (names only) ---'
find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f -iname 'Zebra-*.ips' -print 2>/dev/null | tail -n 8 || true

echo 'zebra_ab_test_complete=true'
exit 0
