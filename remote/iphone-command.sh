#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
SSID='bootybandit1'
WORDLIST='/var/mobile/bootybandit1-wordlist.txt'
AIRMON='/var/jb/usr/sbin/airmon-ng'

echo '=== OWNED WIFI AIRMON INSTALL + TEST ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== INSTALL CURL IF NEEDED =====\n'
if ! command -v curl >/dev/null 2>&1; then
  apt-get update 2>&1 | tail -n 60
  apt-get install -y curl 2>&1 | tail -n 100
  echo "apt_install_curl_rc=$?"
fi
command -v curl 2>/dev/null || true

printf '\n===== INSTALL UPSTREAM AIRMON-NG =====\n'
if command -v curl >/dev/null 2>&1; then
  curl -fL --connect-timeout 15 --max-time 45 \
    'https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/master/scripts/airmon-ng.linux' \
    -o "$AIRMON" 2>&1
  crc=$?
  echo "airmon_download_rc=$crc"
  if [ "$crc" -eq 0 ] && [ -s "$AIRMON" ]; then
    chmod 755 "$AIRMON"
    echo "airmon_installed=$AIRMON"
  fi
else
  echo 'airmon_install_result=curl-still-missing'
fi
ls -l "$AIRMON" 2>/dev/null || true

printf '\n===== AIRMON PREREQUISITES =====\n'
for p in /sys /sys/class /sys/class/net /sys/class/ieee80211 /proc; do
  if [ -e "$p" ]; then echo "$p=PRESENT"; else echo "$p=MISSING"; fi
done
for b in iw ethtool awk grep ifconfig ip; do
  q=$(command -v "$b" 2>/dev/null)
  [ -n "$q" ] && echo "$b=$q" || echo "$b=NOT_FOUND"
done

printf '\n===== TRY AIRMON-NG START EN0 =====\n'
MON_OK=0
if [ -x "$AIRMON" ]; then
  "$AIRMON" start en0 > /tmp/airmon-start.txt 2>&1
  arc=$?
  cat /tmp/airmon-start.txt 2>/dev/null || true
  echo "airmon_start_rc=$arc"
  [ "$arc" -eq 0 ] && MON_OK=1
else
  echo 'airmon_start_result=not-installed'
fi

printf '\n===== INTERFACES AFTER TEST =====\n'
for cmd in ifconfig ipconfig networksetup; do command -v "$cmd" 2>/dev/null || true; done
ifconfig -l 2>/dev/null || true
ifconfig en0 2>/dev/null | head -n 60 || true

printf '\n===== PASSIVE CAPTURE ONLY IF MONITOR MODE SUCCEEDED =====\n'
if [ "$MON_OK" -eq 1 ]; then
  rm -f /var/mobile/bootybandit1-monitor-* 2>/dev/null || true
  MON_IF='en0'
  for i in en0mon wlan0mon wlan1mon mon0; do
    if ifconfig "$i" >/dev/null 2>&1; then MON_IF="$i"; break; fi
  done
  echo "monitor_interface=$MON_IF"
  airodump-ng --write /var/mobile/bootybandit1-monitor --output-format pcap "$MON_IF" > /tmp/airodump-monitor.txt 2>&1 &
  APID=$!
  sleep 10
  kill -9 "$APID" >/dev/null 2>&1 || true
  sleep 1
  tail -n 80 /tmp/airodump-monitor.txt 2>/dev/null || true
else
  echo 'capture_skipped=monitor-mode-not-available'
fi

printf '\n===== SEARCH + OFFLINE WORDLIST TEST =====\n'
CAPS='/tmp/aircrack-caps.txt'
: > "$CAPS"
for root in /var/mobile /var/root /var/jb/var/mobile /var/jb/tmp /tmp; do
  [ -d "$root" ] || continue
  find "$root" -xdev -type f \( -iname '*.cap' -o -iname '*.pcap' -o -iname '*.pcapng' \) -size +0c -print 2>/dev/null | head -n 100 >> "$CAPS"
done
sort -u "$CAPS" -o "$CAPS" 2>/dev/null || true
cat "$CAPS" 2>/dev/null || true
cap_count=$(wc -l < "$CAPS" 2>/dev/null | tr -d ' ')
echo "capture_count=${cap_count:-0}"
if [ -s "$WORDLIST" ] && [ -s "$CAPS" ]; then
  while IFS= read -r cap; do
    [ -f "$cap" ] || continue
    echo "--- testing_capture=$cap ---"
    aircrack-ng -w "$WORDLIST" -e "$SSID" "$cap" 2>&1 | tail -n 120
    echo "aircrack_rc=$?"
  done < "$CAPS"
else
  echo 'result=no-capture-to-crack'
fi

echo '=== END OWNED WIFI AIRMON INSTALL + TEST ==='
