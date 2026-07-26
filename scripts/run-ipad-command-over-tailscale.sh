#!/usr/bin/env bash
set -euo pipefail

HOST="${1:?missing iPad host}"
COMMAND_FILE="${2:?missing command file}"
OUTPUT_FILE="${3:-ipad-output.txt}"
PORT="${IPAD_PORT:-22}"
USER_NAME="${IPAD_USER:-mobile}"

: "${SSHPASS:?SSHPASS is required}"
: "${IPAD_PASSWORD:?IPAD_PASSWORD is required}"
test -s "$COMMAND_FILE"

: > "$OUTPUT_FILE"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

connected=0
for attempt in $(seq 1 45); do
  if ssh-keyscan -T 8 -H -p "$PORT" "$HOST" > "$HOME/.ssh/known_hosts" 2>>"$OUTPUT_FILE"; then
    connected=1
    break
  fi
  echo "ssh_host_key_attempt=$attempt" >> "$OUTPUT_FILE"
  sleep 5
done

echo "ssh_host_key_connected=$connected" | tee -a "$OUTPUT_FILE"
test "$connected" -eq 1
chmod 600 "$HOME/.ssh/known_hosts"

set +e
{
  printf '%s\n' "$IPAD_PASSWORD"
  cat "$COMMAND_FILE"
} | sshpass -e ssh \
      -p "$PORT" \
      -o BatchMode=no \
      -o ConnectTimeout=20 \
      -o ConnectionAttempts=2 \
      -o ServerAliveInterval=15 \
      -o ServerAliveCountMax=4 \
      -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
      "$USER_NAME@$HOST" \
      'SHELL_PATH="$(command -v sh || true)"; [ -n "$SHELL_PATH" ] || SHELL_PATH=/var/jb/bin/sh; sudo -k; exec sudo -S -p "" "$SHELL_PATH" -s' \
      2>&1 | tee -a "$OUTPUT_FILE"
ssh_status=${PIPESTATUS[1]}
set -e

echo "ssh_exit_code=$ssh_status" | tee -a "$OUTPUT_FILE"
exit "$ssh_status"
