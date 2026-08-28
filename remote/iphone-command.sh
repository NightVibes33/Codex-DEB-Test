#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist
PCAP=/var/mobile/tcpdump-rfmon.pcap
TD=/var/jb/usr/local/bin/tcpdump-rfmon
LOG=/tmp/tcpdump-rfmon.log

echo '=== PROCursus LIBPCAP RFMOn TEST ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

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

if [ -x "$RFMON" ] && [ -n "$LDID" ]; then
  "$LDID" -S"$ENT" "$RFMON" 2>&1
  echo "rfmon_sign_rc=$?"
  "$RFMON" en0 off 2>&1 || true
fi

printf '\n===== STORAGE =====\n'
df -h /var /var/jb 2>&1 || true

printf '\n===== TCPDUMP PACKAGE =====\n'
if command -v apt-cache >/dev/null 2>&1; then
  apt-cache policy tcpdump 2>&1 | head -n 80 || true
fi

TCPDUMP_BIN=$(command -v tcpdump 2>/dev/null)
if [ -z "$TCPDUMP_BIN" ] && command -v apt-get >/dev/null 2>&1; then
  echo 'tcpdump_install=attempting'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update 2>&1 | tail -n 80
  apt-get install -y tcpdump 2>&1 | tail -n 120
  echo "tcpdump_install_rc=$?"
  TCPDUMP_BIN=$(command -v tcpdump 2>/dev/null)
fi

echo "tcpdump_bin=${TCPDUMP_BIN:-missing}"
if [ -z "$TCPDUMP_BIN" ]; then
  echo 'result=no-tcpdump-package'
  exit 0
fi

mkdir -p /var/jb/usr/local/bin
cp -f "$TCPDUMP_BIN" "$TD"
chmod 755 "$TD"
if [ -n "$LDID" ]; then
  "$LDID" -S"$ENT" "$TD" 2>&1
  echo "tcpdump_sign_rc=$?"
fi

printf '\n===== TCPDUMP BUILD =====\n'
"$TD" --version 2>&1 | head -n 40 || true
printf '\n===== PCAP DEVICES =====\n'
"$TD" -D 2>&1 | head -n 120 || true
printf '\n===== EN0 LINK TYPES =====\n'
"$TD" -L -i en0 2>&1 | head -n 120 || true

printf '\n===== GUARDED TCPDUMP -I CAPTURE =====\n'
rm -f "$PCAP" "$LOG" /tmp/tcpdump-rfmon-recovery.txt 2>/dev/null || true
nohup sh -c '
  sleep 16
  /var/jb/usr/local/bin/rfmonctl en0 off >>/tmp/tcpdump-rfmon-recovery.txt 2>&1 || true
  killall tcpdump-rfmon >>/tmp/tcpdump-rfmon-recovery.txt 2>&1 || true
  killall wifid >>/tmp/tcpdump-rfmon-recovery.txt 2>&1 || true
' >/dev/null 2>&1 </dev/null &

nohup "$TD" -I -i en0 -s 0 -U -w "$PCAP" >"$LOG" 2>&1 </dev/null &
TPID=$!
echo "tcpdump_pid=$TPID"
sleep 2
printf '\n-- state while tcpdump -I is active --\n'
if [ -x "$RFMON" ]; then "$RFMON" en0 get 2>&1 || true; fi
ls -l "$PCAP" 2>&1 || true
sleep 5
kill "$TPID" 2>/dev/null || true
sleep 2
if [ -x "$RFMON" ]; then "$RFMON" en0 off 2>&1 || true; fi

printf '\n===== TCPDUMP LOG =====\n'
cat "$LOG" 2>/dev/null | tail -n 160 || true
printf '\n===== TCPDUMP PCAP =====\n'
ls -l "$PCAP" 2>&1 || true
if [ -s "$PCAP" ]; then
  echo "pcap_bytes=$(wc -c < "$PCAP" 2>/dev/null | tr -d ' ')"
  echo '-- tcpdump readback --'
  "$TD" -n -r "$PCAP" -c 20 2>&1 | head -n 100 || true
  if command -v aircrack-ng >/dev/null 2>&1; then
    echo '-- aircrack parse --'
    aircrack-ng "$PCAP" 2>&1 | tail -n 120 || true
  fi
else
  echo 'pcap_created=no'
fi

printf '\n===== FINAL STATE =====\n'
if [ -x "$RFMON" ]; then
  "$RFMON" en0 off 2>&1 || true
  "$RFMON" en0 get 2>&1 || true
fi
cat /tmp/tcpdump-rfmon-recovery.txt 2>/dev/null || true

echo '=== END PROCursus LIBPCAP RFMOn TEST ==='
