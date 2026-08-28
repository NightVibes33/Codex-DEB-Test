#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist
TRACE=/tmp/rfmon-interface-trace.txt

echo '=== IOS MONITOR INTERFACE + CHANNEL TRACE ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

if [ ! -x "$RFMON" ] || [ -z "$LDID" ]; then
  echo 'result=missing-rfmonctl-or-ldid'
  exit 0
fi

cat > "$ENT" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.wifi.manager-access</key><true/>
  <key>com.apple.wlan.authentication</key><true/>
  <key>com.apple.security.iokit-user-client-class</key>
  <array><string>IO80211APIUserClient</string></array>
</dict></plist>
PLIST

"$LDID" -S"$ENT" "$RFMON" 2>&1
echo "ldid_sign_rc=$?"

snapshot() {
  label="$1"
  echo "===== $label ====="
  echo "date=$(date 2>/dev/null)"
  echo '-- monitor value --'
  "$RFMON" en0 get 2>&1 || true
  echo '-- interface names --'
  ifconfig -l 2>&1 || true
  echo '-- ifconfig en0 --'
  ifconfig en0 2>&1 || true
  echo '-- all interfaces (trimmed) --'
  ifconfig -a 2>&1 | head -n 260 || true
  echo '-- netstat interfaces --'
  netstat -i 2>&1 | head -n 120 || true
  echo '-- IO80211Interface registry --'
  if command -v ioreg >/dev/null 2>&1; then
    ioreg -r -c IO80211Interface -l -w 0 2>&1 | grep -Ei 'IO80211|BSD Name|BSDName|Channel|SSID|BSSID|Monitor|IOInterface|IOName' | head -n 180 || true
    echo '-- IO80211InterfaceMonitor registry --'
    ioreg -r -c IO80211InterfaceMonitor -l -w 0 2>&1 | head -n 180 || true
  else
    echo 'ioreg=not-installed'
  fi
  echo '-- likely wifi/capture binaries --'
  find /usr/bin /usr/sbin /usr/libexec /var/jb/usr/bin /var/jb/usr/sbin -maxdepth 1 -type f 2>/dev/null | grep -Ei '/(wifi|airport|80211|corecapture|capture|tcpdump|wdutil|skywalk)' | head -n 120 || true
}

rm -f "$TRACE" /tmp/rfmon-hard-recovery.txt 2>/dev/null || true
"$RFMON" en0 off >/dev/null 2>&1 || true
sleep 1
snapshot BASELINE | tee -a "$TRACE"

# Recovery is independent of this SSH process.
nohup sh -c '
  sleep 12
  /var/jb/usr/local/bin/rfmonctl en0 off >>/tmp/rfmon-hard-recovery.txt 2>&1 || true
  killall wifid >>/tmp/rfmon-hard-recovery.txt 2>&1 || true
' >/dev/null 2>&1 </dev/null &

printf '\n===== ENTER MODE 2 =====\n' | tee -a "$TRACE"
"$RFMON" en0 mode 2 2>&1 | tee -a "$TRACE"
echo "mode2_set_rc=$?" | tee -a "$TRACE"
sleep 1
snapshot MODE2 | tee -a "$TRACE"

printf '\n===== LEAVE MODE 2 =====\n' | tee -a "$TRACE"
"$RFMON" en0 off 2>&1 | tee -a "$TRACE"
sleep 1
snapshot RESTORED | tee -a "$TRACE"

printf '\n===== HARD RECOVERY LOG =====\n'
cat /tmp/rfmon-hard-recovery.txt 2>/dev/null || true

echo '=== END IOS MONITOR INTERFACE + CHANNEL TRACE ==='
