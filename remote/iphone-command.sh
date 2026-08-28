#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
TD=/var/jb/usr/local/bin/tcpdump-rfmon
LOG=/var/mobile/native-monitor-disassoc.log
P_RF=/var/mobile/native-mode1-rfmon.pcap
P_EN=/var/mobile/native-mode1-en10mb.pcap

echo '=== READBACK DISASSOCIATED STOCK MODE-1 TEST ==='
echo "readback_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"

printf '\n===== CURRENT RADIO/WIFI STATE =====\n'
if [ -x "$RFMON" ]; then
  "$RFMON" en0 off 2>&1 || true
  "$RFMON" en0 get 2>&1 || true
fi
if [ -x "$TD" ]; then
  "$TD" -D 2>&1 | head -n 50 || true
fi

printf '\n===== WORKER LOG =====\n'
if [ -f "$LOG" ]; then
  cat "$LOG"
else
  echo 'worker_log=missing'
fi

for P in "$P_RF" "$P_EN"; do
  printf '\n===== PCAP %s =====\n' "$P"
  ls -l "$P" 2>&1 || true
  if [ -s "$P" ]; then
    BYTES=$(wc -c < "$P" 2>/dev/null | tr -d ' ')
    echo "pcap_bytes=${BYTES:-0}"
    if [ -x "$TD" ]; then
      echo '-- tcpdump readback --'
      "$TD" -n -e -vv -r "$P" -c 40 2>&1 | head -n 180 || true
    fi
    if command -v aircrack-ng >/dev/null 2>&1; then
      echo '-- aircrack parse --'
      aircrack-ng "$P" 2>&1 | tail -n 160 || true
    fi
  fi
done

printf '\n===== CAPTURE PROCESS CHECK =====\n'
ps ax 2>/dev/null | grep -E '[t]cpdump-rfmon|[n]ative-monitor-disassoc-worker' || true

echo '=== END READBACK ==='
