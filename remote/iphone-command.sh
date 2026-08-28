#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist
TD=/var/jb/usr/local/bin/tcpdump-rfmon
WORKER=/var/mobile/native-monitor-disassoc-worker.sh
LOG=/var/mobile/native-monitor-disassoc.log
PCAP_RF=/var/mobile/native-mode1-rfmon.pcap
PCAP_EN=/var/mobile/native-mode1-en10mb.pcap

echo '=== ARM DETACHED DISASSOCIATED NATIVE MONITOR TEST ==='
echo "armed_at=$(date 2>/dev/null)"
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

if [ ! -x "$RFMON" ] || [ -z "$LDID" ]; then
  echo 'result=missing-rfmonctl-or-ldid'
  exit 0
fi

"$LDID" -S"$ENT" "$RFMON" 2>&1
echo "rfmon_sign_rc=$?"
"$RFMON" en0 off 2>&1 || true
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

rm -f "$LOG" "$PCAP_RF" "$PCAP_EN" \
  /var/mobile/native-mode1-rfmon-tcpdump.log \
  /var/mobile/native-mode1-en10mb-tcpdump.log 2>/dev/null || true

cat > "$WORKER" <<'WORKER_EOF'
#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RF=/var/jb/usr/local/bin/rfmonctl
TD=/var/jb/usr/local/bin/tcpdump-rfmon
LOG=/var/mobile/native-monitor-disassoc.log
P_RF=/var/mobile/native-mode1-rfmon.pcap
P_EN=/var/mobile/native-mode1-en10mb.pcap
TLOG_RF=/var/mobile/native-mode1-rfmon-tcpdump.log
TLOG_EN=/var/mobile/native-mode1-en10mb-tcpdump.log
exec >>"$LOG" 2>&1

echo '=== DISASSOCIATED STOCK MODE-1 WORKER ==='
echo "worker_start=$(date 2>/dev/null)"
echo "pid=$$"

echo '===== BASELINE ====='
"$RF" en0 off || true
"$RF" en0 get || true
"$TD" -D 2>&1 | head -n 40 || true
ps ax 2>/dev/null | grep '[w]ifid' | head -n 10 || true

# Keep wifid from immediately re-associating while the direct Broadcom
# disassociation + monitor capture is in progress.
echo '===== FREEZE WIFID + DISASSOCIATE ====='
killall -STOP wifid 2>&1
echo "wifid_stop_rc=$?"
"$RF" en0 disassoc
echo "disassoc_rc=$?"
sleep 2
"$TD" -D 2>&1 | head -n 40 || true

# Open both the Apple/libpcap rfmon descriptor and a normal en0 descriptor
# before enabling stock native monitor mode 1. This tells us which path, if
# either, receives the raw monitor stream.
echo '===== OPEN CAPTURE DESCRIPTORS ====='
"$TD" -I -i en0 -s 0 -U -w "$P_RF" >"$TLOG_RF" 2>&1 &
PID_RF=$!
"$TD" -i en0 -s 0 -U -w "$P_EN" >"$TLOG_EN" 2>&1 &
PID_EN=$!
echo "tcpdump_rf_pid=$PID_RF tcpdump_en_pid=$PID_EN"
sleep 1

# Mode 1 is Broadcom's stock/native monitor path; unlike mode 2, it does not
# depend on a Nexmon radiotap firmware patch.
echo '===== ENABLE STOCK NATIVE MONITOR MODE 1 ====='
"$RF" en0 raw
echo "mode1_set_rc=$?"
sleep 2
"$RF" en0 get || true

sleep 8

echo '===== CAPTURE WINDOW END ====='
"$RF" en0 get || true
ls -l "$P_RF" "$P_EN" 2>&1 || true

# Restore radio before waking/restarting wifid.
echo '===== RESTORE RADIO + WIFI ====='
"$RF" en0 off || true
kill "$PID_RF" "$PID_EN" 2>/dev/null || true
sleep 2
killall -CONT wifid 2>&1 || true
sleep 1
killall -9 wifid 2>&1 || true
sleep 15
"$RF" en0 off || true
"$RF" en0 get || true
"$TD" -D 2>&1 | head -n 40 || true

for P in "$P_RF" "$P_EN"; do
  echo "===== RESULT $P ====="
  ls -l "$P" 2>&1 || true
  if [ -s "$P" ]; then
    echo "pcap_bytes=$(wc -c < "$P" 2>/dev/null | tr -d ' ')"
    "$TD" -n -r "$P" -c 25 2>&1 | head -n 120 || true
    if command -v aircrack-ng >/dev/null 2>&1; then
      aircrack-ng "$P" 2>&1 | tail -n 100 || true
    fi
  fi
done

echo '===== TCPDUMP RFMON LOG ====='
cat "$TLOG_RF" 2>/dev/null | tail -n 100 || true
echo '===== TCPDUMP EN0 LOG ====='
cat "$TLOG_EN" 2>/dev/null | tail -n 100 || true

echo "worker_end=$(date 2>/dev/null)"
echo 'worker_complete=yes'
WORKER_EOF
chmod 755 "$WORKER"

# Return the SSH command successfully before the worker deliberately drops the
# Wi-Fi association. The next bridge run reads the persistent result files.
nohup sh -c 'sleep 4; exec /var/mobile/native-monitor-disassoc-worker.sh' \
  >/dev/null 2>&1 </dev/null &
WPID=$!
echo "detached_worker_pid=$WPID"
echo "worker_log=$LOG"
echo "rfmon_pcap=$PCAP_RF"
echo "en0_pcap=$PCAP_EN"
echo 'armed=yes; worker will disassociate Wi-Fi after this SSH command returns'
echo '=== DETACHED TEST ARMED ==='
