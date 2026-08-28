#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist
OUT=/tmp/rfmon-capture-result.txt
PCAP=/var/mobile/bootybandit1-rfmon.pcap
WORDLIST=/var/mobile/bootybandit1-wordlist.txt
SSID='bootybandit1'

echo '=== IOS NATIVE MONITOR + BPF PASSIVE CAPTURE ==='
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

printf '\n===== SIGN NATIVE TOOL =====\n'
"$LDID" -S"$ENT" "$RFMON" 2>&1
SIGN_RC=$?
echo "ldid_sign_rc=$SIGN_RC"
if [ "$SIGN_RC" -ne 0 ]; then exit 0; fi

printf '\n===== FORCE CLEAN NON-MONITOR BASELINE =====\n'
"$RFMON" en0 off 2>&1 || true
sleep 1
"$RFMON" en0 get 2>&1
BASE_RC=$?
echo "baseline_get_rc=$BASE_RC"
if [ "$BASE_RC" -ne 0 ]; then
  echo 'capture_skipped=baseline-get-failed'
  exit 0
fi

printf '\n===== BPF DEVICES =====\n'
ls -la /dev/bpf* 2>&1 | head -n 80 || true

printf '\n===== ARM LOCAL RECOVERY + DETACHED PASSIVE CAPTURE =====\n'
rm -f "$OUT" "$PCAP" /tmp/rfmon-hard-recovery.txt /tmp/rfmon-monitor-transition.txt 2>/dev/null || true
# Fallback restores monitor-off locally even if monitor mode interrupts SSH.
nohup sh -c '
  sleep 14
  /var/jb/usr/local/bin/rfmonctl en0 off >>/tmp/rfmon-hard-recovery.txt 2>&1 || true
  killall wifid >>/tmp/rfmon-hard-recovery.txt 2>&1 || true
' >/dev/null 2>&1 </dev/null &

# Start BPF first so DLT 127 is selected while the interface is still in station mode.
nohup sh -c '
  RF=/var/jb/usr/local/bin/rfmonctl
  OUT=/tmp/rfmon-capture-result.txt
  PCAP=/var/mobile/bootybandit1-rfmon.pcap
  : > "$OUT"
  date >> "$OUT" 2>&1
  "$RF" en0 capture "$PCAP" 8 >> "$OUT" 2>&1
  RC=$?
  echo "capture_command_rc=$RC" >> "$OUT"
  ls -l "$PCAP" >> "$OUT" 2>&1 || true
' >/dev/null 2>&1 </dev/null &
CAP_PID=$!
echo "capture_worker_pid=$CAP_PID"

# DLT 127 alone does not flip Broadcom WLC monitor state on iOS 15.8.8.
# Give capture time to bind en0/select radiotap, then enable monitor explicitly.
sleep 2
printf '\n===== EXPLICIT WLC MONITOR AFTER DLT 127 =====\n' | tee -a /tmp/rfmon-monitor-transition.txt
"$RFMON" en0 get 2>&1 | tee -a /tmp/rfmon-monitor-transition.txt
"$RFMON" en0 on 2>&1 | tee -a /tmp/rfmon-monitor-transition.txt
MON_ON_RC=$?
echo "monitor_after_dlt_on_rc=$MON_ON_RC" | tee -a /tmp/rfmon-monitor-transition.txt
"$RFMON" en0 get 2>&1 | tee -a /tmp/rfmon-monitor-transition.txt
sleep 4
"$RFMON" en0 off 2>&1 | tee -a /tmp/rfmon-monitor-transition.txt
MON_OFF_RC=$?
echo "monitor_after_capture_off_rc=$MON_OFF_RC" | tee -a /tmp/rfmon-monitor-transition.txt
"$RFMON" en0 get 2>&1 | tee -a /tmp/rfmon-monitor-transition.txt

sleep 4
printf '\n===== MONITOR TRANSITION =====\n'
cat /tmp/rfmon-monitor-transition.txt 2>/dev/null || true
printf '\n===== CAPTURE RESULT =====\n'
cat "$OUT" 2>/dev/null || echo 'capture_result_not_yet-readable'
printf '\n===== PCAP FILE =====\n'
ls -l "$PCAP" 2>&1 || true
if [ -s "$PCAP" ]; then
  bytes=$(wc -c < "$PCAP" 2>/dev/null | tr -d ' ')
  echo "pcap_bytes=${bytes:-0}"
else
  echo 'pcap_created=no'
fi

printf '\n===== AIRCRACK PARSE CHECK =====\n'
if [ -s "$PCAP" ] && command -v aircrack-ng >/dev/null 2>&1; then
  aircrack-ng "$PCAP" 2>&1 | tail -n 120
  echo "aircrack_parse_rc=$?"
else
  echo 'aircrack_parse_skipped=no-pcap-or-aircrack'
fi

printf '\n===== OFFLINE TARGET WORDLIST CHECK =====\n'
if [ -s "$PCAP" ] && [ -s "$WORDLIST" ] && command -v aircrack-ng >/dev/null 2>&1; then
  aircrack-ng -w "$WORDLIST" -e "$SSID" "$PCAP" 2>&1 | tail -n 120
  echo "aircrack_wordlist_rc=$?"
else
  echo 'wordlist_check_skipped=missing-pcap-wordlist-or-aircrack'
fi

printf '\n===== FINAL RADIO STATE =====\n'
"$RFMON" en0 off 2>&1 || true
"$RFMON" en0 get 2>&1
echo "final_get_rc=$?"
cat /tmp/rfmon-hard-recovery.txt 2>/dev/null || true

echo '=== END IOS NATIVE MONITOR + BPF PASSIVE CAPTURE ==='
