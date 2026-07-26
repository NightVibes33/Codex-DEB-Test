#!/usr/bin/env bash
set -euo pipefail

HOST="${1:?missing iPad host}"
DEB="${2:?missing DEB path}"
DEVICE_SCRIPT="${3:?missing device proof script}"
OUTPUT="${4:-gif2ani-341-device-proof.txt}"

: "${SSHPASS:?SSHPASS is required}"
: "${IPAD_PASSWORD:?IPAD_PASSWORD is required}"

test -s "$DEB"
test -s "$DEVICE_SCRIPT"

connected=0
for attempt in $(seq 1 45); do
  if sshpass -e ssh -p 22 -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null mobile@"$HOST" true >/dev/null 2>&1; then
    connected=1
    break
  fi
  sleep 5
done

echo "connected=$connected" | tee "$OUTPUT"
test "$connected" -eq 1

sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$DEB" mobile@"$HOST":/var/mobile/Media/Gif2Ani-3.4.1-final.deb
sshpass -e scp -P 22 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$DEVICE_SCRIPT" mobile@"$HOST":/var/mobile/Media/prove-gif2ani-341-device.sh

printf '%s\n' "$IPAD_PASSWORD" | sshpass -e ssh -p 22 -o ConnectTimeout=60 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null mobile@"$HOST" \
  'sudo -S -p "" sh /var/mobile/Media/prove-gif2ani-341-device.sh' 2>&1 | tee -a "$OUTPUT"

grep -qx 'gif2ani_341_device_proof=success' "$OUTPUT"
