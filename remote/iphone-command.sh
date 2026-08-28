#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist
PCAP=/var/mobile/tcpdump-wlc2-rfmon.pcap
TD=/var/jb/usr/local/bin/tcpdump-rfmon
LOG=/tmp/tcpdump-wlc2-rfmon.log
REC=/tmp/tcpdump-wlc2-recovery.txt

echo '=== LIBPCAP RADIOTAP + BROADCOM WLC MODE 2 ==='
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

if [ ! -x "$RFMON" ]; then
  echo 'result=missing-rfmonctl'
  exit 0
fi
if [ -z "$LDID" ]; then
  echo 'result=missing-ldid'
  exit 0
fi

"$LDID" -S"$ENT" "$RFMON" 2>&1
echo "rfmon_sign_rc=$?"
"$RFMON" en0 off 2>&1 || true
sleep 1
"$RFMON" en0 get 2>&1 || true

TCPDUMP_BIN=$(command -v tcpdump 2>/dev/null)
if [ -z "$TCPDUMP_BIN" ]; then
  echo 'result=tcpdump-not-installed'
  exit 0
fi
mkdir -p /var/jb/usr/local/bin
cp -f "$TCPDUMP_BIN" "$TD"
chmod 755 "$TD"
"$LDID" -S"$ENT" "$TD" 2>&1
echo "tcpdump_sign_rc=$?"

printf '\n===== PRECHECK =====\n'
"$TD" --version 2>&1 | head -n 20 || true
"$TD" -L -i en0 2>&1 | head -n 80 || true

rm -f "$PCAP" "$LOG" "$REC" 2>/dev/null || true

# Independent recovery in case monitor mode interrupts the transport.
nohup sh -c '
  sleep 18
  /var/jb/usr/local/bin/rfmonctl en0 off >>/tmp/tcpdump-wlc2-recovery.txt 2>&1 || true
  killall tcpdump-rfmon >>/tmp/tcpdump-wlc2-recovery.txt 2>&1 || true
  killall wifid >>/tmp/tcpdump-wlc2-recovery.txt 2>&1 || true
' >/dev/null 2>&1 </dev/null &

printf '\n===== START LIBPCAP RADIOTAP HANDLE =====\n'
nohup "$TD" -I -i en0 -s 0 -U -w "$PCAP" >"$LOG" 2>&1 </dev/null &
TPID=$!
echo "tcpdump_pid=$TPID"
sleep 2

echo '-- before WLC mode 2 --'
"$RFMON" en0 get 2>&1 || true
ls -l "$PCAP" 2>&1 || true

printf '\n===== ENABLE WLC RADIOTAP MODE 2 =====\n'
"$RFMON" en0 mode 2 2>&1
SET_RC=$?
echo "wlc_mode2_set_rc=$SET_RC"
sleep 1
"$RFMON" en0 get 2>&1
GET_RC=$?
echo "wlc_mode2_get_rc=$GET_RC"

# Capture while libpcap's DLT127 descriptor and firmware mode 2 are both active.
sleep 7
printf '\n===== STATE DURING COMBINED CAPTURE =====\n'
"$RFMON" en0 get 2>&1 || true
ls -l "$PCAP" 2>&1 || true

printf '\n===== RESTORE =====\n'
"$RFMON" en0 off 2>&1 || true
sleep 1
kill "$TPID" 2>/dev/null || true
sleep 2
"$RFMON" en0 get 2>&1 || true

printf '\n===== TCPDUMP LOG =====\n'
cat "$LOG" 2>/dev/null | tail -n 180 || true

printf '\n===== PCAP RESULT =====\n'
ls -l "$PCAP" 2>&1 || true
if [ -s "$PCAP" ]; then
  BYTES=$(wc -c < "$PCAP" 2>/dev/null | tr -d ' ')
  echo "pcap_bytes=${BYTES:-0}"
  echo '-- tcpdump readback --'
  "$TD" -n -r "$PCAP" -c 30 2>&1 | head -n 140 || true
  if command -v aircrack-ng >/dev/null 2>&1; then
    echo '-- aircrack parse --'
    aircrack-ng "$PCAP" 2>&1 | tail -n 140 || true
  fi
else
  echo 'pcap_created=no'
fi

printf '\n===== FINAL RADIO STATE =====\n'
"$RFMON" en0 off 2>&1 || true
"$RFMON" en0 get 2>&1 || true
cat "$REC" 2>/dev/null || true

echo '=== END LIBPCAP RADIOTAP + BROADCOM WLC MODE 2 ==='
