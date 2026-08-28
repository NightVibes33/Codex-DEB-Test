#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
SSID='bootybandit1'
WORDLIST='/var/mobile/bootybandit1-wordlist.txt'
CAPBASE='/var/mobile/bootybandit1-monitor-test'

echo '=== OWNED WIFI AIRMON/AIRCRACK TEST ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== CURRENT AIRCRACK INSTALL =====\n'
for b in aircrack-ng airodump-ng aireplay-ng airmon-ng airbase-ng packetforge-ng curl apt-get apt-cache dpkg; do
  p=$(command -v "$b" 2>/dev/null)
  [ -n "$p" ] && echo "$b=$p" || echo "$b=NOT_FOUND"
done

printf '\n===== PACKAGE CONTENTS / REPO CHECK =====\n'
dpkg -L aircrack-ng 2>/dev/null | grep -i 'airmon' || echo 'aircrack-ng package contains no airmon-ng'
apt-cache search airmon-ng 2>/dev/null | head -n 20 || true
apt-cache search aircrack 2>/dev/null | head -n 30 || true

printf '\n===== INSTALL UPSTREAM AIRMON-NG SCRIPT =====\n'
AIRMON='/var/jb/usr/sbin/airmon-ng'
if [ ! -x "$AIRMON" ]; then
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 15 --max-time 45 \
      'https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/master/scripts/airmon-ng.linux' \
      -o "$AIRMON" 2>&1
    crc=$?
    echo "curl_rc=$crc"
    if [ "$crc" -eq 0 ] && [ -s "$AIRMON" ]; then
      chmod 755 "$AIRMON"
      echo "installed_airmon_ng=$AIRMON"
    else
      rm -f "$AIRMON" 2>/dev/null || true
      echo 'install_result=download-failed'
    fi
  else
    echo 'install_result=curl-not-found'
  fi
else
  echo "airmon_ng_already_present=$AIRMON"
fi
ls -l "$AIRMON" 2>/dev/null || true

printf '\n===== PLATFORM PREREQUISITES =====\n'
for p in /sys /sys/class /sys/class/net /sys/class/ieee80211 /proc; do
  if [ -e "$p" ]; then echo "$p=PRESENT"; else echo "$p=MISSING"; fi
done
for b in iw ethtool awk grep ifconfig ip; do
  q=$(command -v "$b" 2>/dev/null)
  [ -n "$q" ] && echo "$b=$q" || echo "$b=NOT_FOUND"
done

printf '\n===== TRY MONITOR MODE ON EN0 =====\n'
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

echo 'interfaces_after_airmon:'
ifconfig -l 2>/dev/null || true
ifconfig en0 2>/dev/null | head -n 60 || true

printf '\n===== PASSIVE CAPTURE IF MONITOR MODE ACTUALLY SUCCEEDED =====\n'
rm -f "${CAPBASE}"-* 2>/dev/null || true
if [ "$MON_OK" -eq 1 ]; then
  MON_IF=''
  for i in en0mon wlan0mon wlan1mon mon0; do
    if ifconfig "$i" >/dev/null 2>&1; then MON_IF="$i"; break; fi
  done
  [ -z "$MON_IF" ] && MON_IF='en0'
  echo "monitor_interface=$MON_IF"
  airodump-ng --write "$CAPBASE" --output-format pcap "$MON_IF" > /tmp/airodump-monitor.txt 2>&1 &
  APID=$!
  echo "airodump_pid=$APID"
  sleep 10
  kill -9 "$APID" >/dev/null 2>&1 || true
  sleep 1
  tail -n 80 /tmp/airodump-monitor.txt 2>/dev/null || true
else
  echo 'capture_skipped=monitor-mode-not-available'
fi

printf '\n===== SEARCH FOR WPA CAPTURES =====\n'
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

printf '\n===== OFFLINE PASSWORD TEST =====\n'
if [ ! -s "$WORDLIST" ]; then
  echo 'result=wordlist-missing'
elif [ ! -s "$CAPS" ]; then
  echo 'result=no-capture-to-crack'
else
  while IFS= read -r cap; do
    [ -f "$cap" ] || continue
    echo "--- testing_capture=$cap ---"
    aircrack-ng -w "$WORDLIST" -e "$SSID" "$cap" 2>&1 | tail -n 120
    echo "aircrack_rc=$?"
  done < "$CAPS"
fi

echo '=== END OWNED WIFI AIRMON/AIRCRACK TEST ==='
