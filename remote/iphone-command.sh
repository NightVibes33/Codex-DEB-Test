#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
SSID='bootybandit1'
WORDLIST='/var/mobile/bootybandit1-wordlist.txt'

echo '=== OWNED WIFI AIRCRACK AUDIT ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== AIRCRACK SUITE =====\n'
for b in aircrack-ng airodump-ng aireplay-ng airmon-ng airbase-ng packetforge-ng; do
  p=$(command -v "$b" 2>/dev/null)
  [ -n "$p" ] && echo "$b=$p" || echo "$b=NOT_FOUND"
done
aircrack-ng --help 2>&1 | head -n 8 || true

printf '\n===== NETWORK INTERFACES =====\n'
command -v ifconfig 2>/dev/null || true
ifconfig -l 2>/dev/null || true
ifconfig en0 2>/dev/null | head -n 80 || true
ipconfig getifaddr en0 2>/dev/null || true

printf '\n===== BUILD TARGETED WORDLIST FOR OWN SSID =====\n'
TMP="/tmp/bootybandit-wordlist.$$"
: > "$TMP"
for base in bootybandit BootyBandit Bootybandit BOOTYBANDIT bootybandit1 BootyBandit1 Bootybandit1 BOOTYBANDIT1; do
  echo "$base" >> "$TMP"
  for y in 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026; do
    printf '%s%s\n' "$base" "$y" >> "$TMP"
    printf '%s%s!\n' "$base" "$y" >> "$TMP"
  done
  for n in $(seq 0 999 2>/dev/null); do
    printf '%s%s\n' "$base" "$n" >> "$TMP"
  done
  for s in '!' '@' '#' '$' '!!' '123' '1234' '12345' '01' '007'; do
    printf '%s%s\n' "$base" "$s" >> "$TMP"
  done
done
# Every generated candidate is already within WPA/WPA2's 8..63 character range.
sort -u "$TMP" > "$WORDLIST"
rm -f "$TMP"
chmod 600 "$WORDLIST" 2>/dev/null || true
wc -l "$WORDLIST" 2>/dev/null || true
printf 'wordlist_path=%s\n' "$WORDLIST"
printf 'sample:\n'
head -n 20 "$WORDLIST" 2>/dev/null || true

printf '\n===== PASSIVE AIRODUMP PROBE ON EN0 =====\n'
rm -f /tmp/airodump-en0.out /var/mobile/bootybandit-passive-*.cap /var/mobile/bootybandit-passive-*.csv 2>/dev/null || true
if command -v airodump-ng >/dev/null 2>&1; then
  airodump-ng --write /var/mobile/bootybandit-passive --output-format pcap en0 > /tmp/airodump-en0.out 2>&1 &
  apid=$!
  sleep 8
  kill "$apid" >/dev/null 2>&1 || true
  wait "$apid" >/dev/null 2>&1 || true
  echo 'airodump_output:'
  tail -n 80 /tmp/airodump-en0.out 2>/dev/null || true
else
  echo 'airodump-ng not installed'
fi

printf '\n===== SEARCH FOR CAPTURES =====\n'
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

printf '\n===== OFFLINE TEST AGAINST OWN SSID =====\n'
if ! command -v aircrack-ng >/dev/null 2>&1; then
  echo 'result=aircrack-ng-not-installed'
elif [ ! -s "$CAPS" ]; then
  echo 'result=no-existing-capture-found'
  echo 'note=No offline crack can be attempted without a WPA/WPA2 handshake/PMKID capture.'
else
  while IFS= read -r cap; do
    [ -f "$cap" ] || continue
    echo "--- testing_capture=$cap ---"
    aircrack-ng -w "$WORDLIST" -e "$SSID" "$cap" 2>&1 | tail -n 100
    echo "aircrack_rc=$?"
  done < "$CAPS"
fi

printf '\n===== END OWNED WIFI AIRCRACK AUDIT =====\n'
