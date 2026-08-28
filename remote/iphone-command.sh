#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo '=== IOS WIFI CAPTURE CONTROL-PLANE INVENTORY ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== BPF / PACKET CAPTURE DEVICES =====\n'
ls -la /dev/bpf* 2>&1 | head -n 120 || true
ls -la /dev/pktap* 2>&1 | head -n 80 || true

printf '\n===== PACKAGE CACHE: PCAP / TCPDUMP / NETWORK TOOLS =====\n'
for q in tcpdump libpcap network-cmds inetutils adv-cmds; do
  echo "--- apt-cache search: $q ---"
  apt-cache search "$q" 2>&1 | head -n 80 || true
done
printf '\n--- installed related packages ---\n'
dpkg -l 2>/dev/null | grep -Ei 'tcpdump|libpcap|network-cmds|inetutils|adv-cmds|corecapture|apple80211' | head -n 120 || true

printf '\n===== PRIVATE FRAMEWORK CONTENTS =====\n'
for fw in \
  /System/Library/PrivateFrameworks/Apple80211.framework \
  /System/Library/PrivateFrameworks/CoreCapture.framework \
  /System/Library/PrivateFrameworks/CoreCaptureControl.framework \
  /System/Library/PrivateFrameworks/WiFiKit.framework \
  /System/Library/PrivateFrameworks/WiFiPolicy.framework \
  /System/Library/PrivateFrameworks/WirelessDiagnostics.framework; do
  if [ -e "$fw" ]; then
    echo "--- $fw ---"
    ls -la "$fw" 2>&1 | head -n 100
    find "$fw" -maxdepth 5 -type f -print 2>/dev/null | head -n 160
  fi
done

printf '\n===== WIFI / CAPTURE EXECUTABLES =====\n'
for root in /usr/bin /usr/sbin /usr/libexec /System/Library/PrivateFrameworks /System/Library/CoreServices; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 4 -type f \( \
    -iname '*wifi*' -o -iname '*wireless*' -o -iname '*80211*' -o \
    -iname '*corecapture*' -o -iname '*capture*' -o -iname '*airport*' \
  \) -print 2>/dev/null | head -n 240
done

printf '\n===== WIFI / CORECATURE LAUNCHD PLISTS =====\n'
PLISTS=/tmp/wifi-launchd-plists.txt
: > "$PLISTS"
for root in /System/Library/LaunchDaemons /System/Library/LaunchAgents /Library/LaunchDaemons /var/jb/Library/LaunchDaemons; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 1 -type f -print 2>/dev/null | grep -Ei 'wifi|wireless|80211|corecapture|capture' >> "$PLISTS"
done
sort -u "$PLISTS" -o "$PLISTS" 2>/dev/null || true
cat "$PLISTS" 2>/dev/null | head -n 160
while IFS= read -r p; do
  [ -f "$p" ] || continue
  sz=$(stat -f %z "$p" 2>/dev/null || wc -c < "$p" 2>/dev/null)
  echo "--- plist=$p size=${sz:-?} ---"
  if [ "${sz:-999999}" -le 32768 ] 2>/dev/null; then
    base64 "$p" 2>/dev/null | tr -d '\n'
    echo
  fi
done < "$PLISTS"

printf '\n===== WIFI DAEMONS / HELP OUTPUT =====\n'
for p in \
  /usr/sbin/wifid \
  /usr/libexec/wifianalyticsd \
  /usr/libexec/wifivelocityd \
  /usr/libexec/wifip2pd \
  /usr/libexec/wifid \
  /System/Library/PrivateFrameworks/WirelessDiagnostics.framework/Support/awdd; do
  [ -x "$p" ] || continue
  echo "--- $p ---"
  ls -l "$p"
  "$p" -h </dev/null 2>&1 | head -n 80 || true
  "$p" --help </dev/null 2>&1 | head -n 80 || true
done

printf '\n===== DYLD / FRAMEWORK BINARY PRESENCE =====\n'
for p in \
  /System/Library/PrivateFrameworks/Apple80211.framework/Apple80211 \
  /System/Library/PrivateFrameworks/CoreCapture.framework/CoreCapture \
  /System/Library/PrivateFrameworks/CoreCaptureControl.framework/CoreCaptureControl; do
  if [ -e "$p" ]; then
    echo "FOUND $p"
    ls -l "$p"
  else
    echo "MISSING_ON_DISK $p (may be dyld-cache-backed)"
  fi
done
ls -l /System/Library/Caches/com.apple.dyld/* 2>/dev/null | head -n 60 || true

printf '\n===== IOKIT MONITOR / USERCLIENT SUMMARY =====\n'
ioreg -l -w0 2>/dev/null | grep -Ei 'IO80211InterfaceMonitor|IO80211ControllerMonitor|IO80211APIUserClient|AppleBCMWLANUserClient|CCCapture|CoreCapture|AppleBCMWLAN.BuildTag|IO80211Family.BuildTag' | head -n 220 || true

printf '\n===== INTERFACE SUMMARY =====\n'
ipconfig getiflist 2>&1 || true
for i in en0 awdl0 llw0 ap1; do
  echo "--- $i ---"
  ipconfig getsummary "$i" 2>&1 | head -n 80 || true
done

echo '=== END IOS WIFI CAPTURE CONTROL-PLANE INVENTORY ==='
