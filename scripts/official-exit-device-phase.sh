#!/usr/bin/env bash
set -euo pipefail

HELPER_PATH="${1:?helper path required}"
: "${IPAD_HOST:?missing IPAD_HOST}"
: "${IPAD_PASSWORD:?missing IPAD_PASSWORD}"
export SSHPASS="$IPAD_PASSWORD"

test -x "$HELPER_PATH"

echo "=== WAIT FOR IPAD SSH ==="
connected=0
for attempt in $(seq 1 48); do
  if sshpass -e ssh -p 22 -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      mobile@"$IPAD_HOST" true >/dev/null 2>&1; then
    connected=1
    break
  fi
  sleep 5
done
test "$connected" -eq 1

sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$HELPER_PATH" mobile@"$IPAD_HOST":/var/mobile/Media/exitpale-v4

cat > prepare-v4.sh <<'SH'
#!/bin/sh
set -eu
media="/var/mobile/Library/Application Support/Gif2Ani"
prefs="/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist"
marker="/var/mobile/Media/gif2ani-official-exit-v4.marker"
test "$(dpkg-query -W com.nightvibes33.gif2ani | cut -f2)" = "3.1.1"
mkdir -p "$media"
printf '%s\n' \
  '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict>' \
  '  <key>isEnabled</key><false/>' \
  '  <key>pendingReady</key><false/>' \
  '  <key>imageTransformation</key><string>resizeAspect</string>' \
  '  <key>customLoop</key><real>-1</real>' \
  '  <key>customDuration</key><real>-1</real>' \
  '  <key>backgroundColor</key><string>#000000</string>' \
  '</dict></plist>' > "$prefs"
chown mobile:mobile "$media" "$prefs"
chmod 0755 "$media"
chmod 0644 "$prefs"
chmod 0755 /var/mobile/Media/exitpale-v4
rm -f "$media/Pending.gif" "$media/Active.gif" "$media/Rejected.gif" "$media/load-in-progress" "$media/runtime-status.plist"
touch "$marker"
echo "prepared_disabled_clean_state=yes"
SH
chmod +x prepare-v4.sh
sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  prepare-v4.sh mobile@"$IPAD_HOST":/var/mobile/Media/
printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=20 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$IPAD_HOST" \
  'sudo -S -p "" sh /var/mobile/Media/prepare-v4.sh'

echo "=== SEND OFFICIAL PALERA1N EXIT SAFE MODE COMMAND ==="
set +e
printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=20 \
  -o ServerAliveInterval=3 -o ServerAliveCountMax=2 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$IPAD_HOST" \
  'sudo -S -p "" /var/mobile/Media/exitpale-v4'
exit_code=$?
set -e
echo "exit_command_ssh_exit=$exit_code"
if [[ "$exit_code" -ne 0 && "$exit_code" -ne 255 ]]; then
  exit "$exit_code"
fi

echo "=== WAIT FOR IPAD AFTER OFFICIAL EXIT ==="
sleep 10
connected=0
for attempt in $(seq 1 72); do
  if sshpass -e ssh -p 22 -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      mobile@"$IPAD_HOST" true >/dev/null 2>&1; then
    connected=1
    break
  fi
  sleep 5
done
echo "reconnected_after_official_exit=$connected"
test "$connected" -eq 1
sleep 10

cat > verify-v4.sh <<'SH'
#!/bin/sh
set -eu
media="/var/mobile/Library/Application Support/Gif2Ani"
marker="/var/mobile/Media/gif2ani-official-exit-v4.marker"
test "$(dpkg-query -W com.nightvibes33.gif2ani | cut -f2)" = "3.1.1"
test ! -e "$media/Pending.gif"
test ! -e "$media/Active.gif"
test ! -e "$media/Rejected.gif"
test ! -e "$media/load-in-progress"
test -f "$media/runtime-status.plist"
cat "$media/runtime-status.plist"
grep -a -q 'tweak-loaded-no-media-decode' "$media/runtime-status.plist"
crashes=$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \( -name 'backboardd-*.ips' -o -name 'SpringBoard-*.ips' \) -newer "$marker" -print 2>/dev/null | wc -l | tr -d ' ')
echo "crashes_after_official_exit=$crashes"
test "$crashes" = "0"
echo "official_exit_and_normal_injection=success"
ps ax | grep -E '[b]ackboardd|[S]pringBoard' || true
SH
chmod +x verify-v4.sh
sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  verify-v4.sh mobile@"$IPAD_HOST":/var/mobile/Media/
printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=20 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$IPAD_HOST" \
  'sudo -S -p "" sh /var/mobile/Media/verify-v4.sh'

echo "device_phase=success"
