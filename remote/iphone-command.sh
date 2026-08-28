#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist
OUT=/tmp/rfmon-pulse-result.txt

echo '=== IOS GUARDED NATIVE RFMON PULSE TEST ==='
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

printf '\n===== SIGN + VERIFY =====\n'
"$LDID" -S"$ENT" "$RFMON" 2>&1
echo "ldid_sign_rc=$?"
"$LDID" -e "$RFMON" 2>&1 | head -n 120

printf '\n===== BASELINE GET =====\n'
"$RFMON" en0 get 2>&1
GET_RC=$?
echo "baseline_get_rc=$GET_RC"
if [ "$GET_RC" -ne 0 ]; then
  echo 'pulse_skipped=baseline-get-failed'
  exit 0
fi

printf '\n===== ARM LOCAL RECOVERY + PULSE =====\n'
rm -f "$OUT" /tmp/rfmon-hard-recovery.txt 2>/dev/null || true
# Hard fallback always attempts monitor-off locally after 7s, even if en0 drops
# the SSH/Tailscale transport during the experiment.
nohup sh -c '
  sleep 7
  /var/jb/usr/local/bin/rfmonctl en0 off >>/tmp/rfmon-hard-recovery.txt 2>&1 || true
  killall wifid >>/tmp/rfmon-hard-recovery.txt 2>&1 || true
' >/dev/null 2>&1 </dev/null &

# Run the actual 2-second test detached so the on-device sequence can complete
# even if switching radio mode tears down this SSH session.
nohup sh -c '
  RF=/var/jb/usr/local/bin/rfmonctl
  OUT=/tmp/rfmon-pulse-result.txt
  : > "$OUT"
  date >> "$OUT" 2>&1
  echo "--- before ---" >> "$OUT"
  "$RF" en0 get >> "$OUT" 2>&1
  echo "before_rc=$?" >> "$OUT"
  echo "--- set on ---" >> "$OUT"
  "$RF" en0 on >> "$OUT" 2>&1
  ONRC=$?
  echo "on_rc=$ONRC" >> "$OUT"
  sleep 1
  echo "--- get while on ---" >> "$OUT"
  "$RF" en0 get >> "$OUT" 2>&1
  echo "while_on_get_rc=$?" >> "$OUT"
  sleep 1
  echo "--- set off ---" >> "$OUT"
  "$RF" en0 off >> "$OUT" 2>&1
  OFFRC=$?
  echo "off_rc=$OFFRC" >> "$OUT"
  sleep 1
  echo "--- after ---" >> "$OUT"
  "$RF" en0 get >> "$OUT" 2>&1
  echo "after_rc=$?" >> "$OUT"
' >/dev/null 2>&1 </dev/null &
echo "pulse_worker_pid=$!"

# Give the detached worker a chance to finish while this SSH session remains up.
sleep 5
printf '\n===== PULSE RESULT =====\n'
cat "$OUT" 2>/dev/null || echo 'pulse_result_not_yet-readable'
printf '\n===== HARD RECOVERY LOG =====\n'
cat /tmp/rfmon-hard-recovery.txt 2>/dev/null || true
printf '\n===== FINAL GET =====\n'
"$RFMON" en0 get 2>&1
echo "final_get_rc=$?"

echo '=== END IOS GUARDED NATIVE RFMON PULSE TEST ==='
