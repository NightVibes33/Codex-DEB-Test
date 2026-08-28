#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo '=== IOS APPLE WIFI CAPTURE PROBE ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== WIFI / CAPTURE PROCESSES =====\n'
ps aux 2>/dev/null | grep -Ei 'wifid|airportd|corecapture|wireless|bluetoothd' | grep -v grep | head -n 80 || true

printf '\n===== AVAILABLE NETWORK TOOLS =====\n'
for b in apple80211 tcpdump pktap rvictl ioreg scutil ipconfig networksetup ifconfig netstat lsof log strings nm otool; do
  q=$(command -v "$b" 2>/dev/null)
  [ -n "$q" ] && echo "$b=$q" || echo "$b=NOT_FOUND"
done

printf '\n===== APPLE80211 / CORECATURE FILE SEARCH =====\n'
for p in \
  /usr/local/bin/apple80211 \
  /usr/bin/apple80211 \
  /usr/sbin/apple80211 \
  /System/Library/PrivateFrameworks/Apple80211.framework/apple80211 \
  /System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport \
  /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport \
  /System/Library/PrivateFrameworks/CoreCaptureControl.framework \
  /System/Library/PrivateFrameworks/CoreCapture.framework \
  /System/Library/Frameworks/CoreCapture.framework; do
  if [ -e "$p" ]; then
    ls -ld "$p" 2>/dev/null || echo "FOUND $p"
  else
    echo "MISSING $p"
  fi
done

printf '\n===== BROADER APPLE WIFI BINARIES =====\n'
for root in /usr/bin /usr/sbin /usr/local/bin /System/Library/PrivateFrameworks/Apple80211.framework /System/Library/PrivateFrameworks/CoreCaptureControl.framework /System/Library/PrivateFrameworks/CoreCapture.framework; do
  [ -e "$root" ] || continue
  find "$root" -maxdepth 4 -type f \( -iname '*apple80211*' -o -iname '*airport*' -o -iname '*corecapture*' -o -iname '*wifi*' \) -print 2>/dev/null | head -n 100
done

printf '\n===== IOREG WIFI DRIVER =====\n'
if command -v ioreg >/dev/null 2>&1; then
  ioreg -l -w0 2>/dev/null | grep -Ei 'AppleBCMWLAN|IO80211|BCM43|WiFi|wlan' | head -n 120 || true
else
  echo 'ioreg_unavailable'
fi

printf '\n===== APPLE80211 READ-ONLY QUERIES =====\n'
APPLE80211=''
for p in "$(command -v apple80211 2>/dev/null)" /usr/local/bin/apple80211 /usr/bin/apple80211 /usr/sbin/apple80211; do
  [ -n "$p" ] || continue
  if [ -x "$p" ]; then APPLE80211="$p"; break; fi
done
if [ -n "$APPLE80211" ]; then
  echo "apple80211_selected=$APPLE80211"
  "$APPLE80211" en0 -driver_ver 2>&1 | head -n 60
  echo "driver_ver_rc=$?"
  "$APPLE80211" en0 -hardware_ver 2>&1 | head -n 60
  echo "hardware_ver_rc=$?"
  "$APPLE80211" en0 -cardcap 2>&1 | head -n 120
  echo "cardcap_rc=$?"
else
  echo 'apple80211_selected=NONE'
fi

printf '\n===== BEFORE CORECATURE FILES =====\n'
BEFORE=/tmp/corecapture-before.txt
AFTER=/tmp/corecapture-after.txt
: > "$BEFORE"
for root in /var/mobile/Library/Logs/CrashReporter /var/root/Library/Logs/CrashReporter /Library/Logs/CrashReporter /var/mobile/Library/Logs /var/root/Library/Logs; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 7 -type f \( -iname '*.pcap' -o -iname '*.pcapng' -o -iname '*.pcap.gz' -o -iname '*.pcapng.gz' \) -print 2>/dev/null >> "$BEFORE"
done
sort -u "$BEFORE" -o "$BEFORE" 2>/dev/null || true
wc -l "$BEFORE" 2>/dev/null || true
tail -n 40 "$BEFORE" 2>/dev/null || true

printf '\n===== REQUEST APPLE CORECATURE =====\n'
if [ -n "$APPLE80211" ]; then
  "$APPLE80211" en0 -capture=ChatGPTWiFiDiagnostic 2>&1 | head -n 120
  echo "capture_request_rc=$?"
  sleep 5
else
  echo 'capture_request_skipped=no-apple80211-binary'
fi

printf '\n===== AFTER CORECATURE FILES =====\n'
: > "$AFTER"
for root in /var/mobile/Library/Logs/CrashReporter /var/root/Library/Logs/CrashReporter /Library/Logs/CrashReporter /var/mobile/Library/Logs /var/root/Library/Logs; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 7 -type f \( -iname '*.pcap' -o -iname '*.pcapng' -o -iname '*.pcap.gz' -o -iname '*.pcapng.gz' \) -print 2>/dev/null >> "$AFTER"
done
sort -u "$AFTER" -o "$AFTER" 2>/dev/null || true
wc -l "$AFTER" 2>/dev/null || true
comm -13 "$BEFORE" "$AFTER" 2>/dev/null | head -n 80 || true

printf '\n===== CORECATURE DIRECTORIES =====\n'
for root in /var/mobile/Library/Logs/CrashReporter /var/root/Library/Logs/CrashReporter /Library/Logs/CrashReporter /var/mobile/Library/Logs /var/root/Library/Logs; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 5 -type d -iname '*CoreCapture*' -print 2>/dev/null | head -n 80
done

echo '=== END IOS APPLE WIFI CAPTURE PROBE ==='
