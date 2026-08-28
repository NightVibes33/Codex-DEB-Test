#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo '=== IPAD LAN PROBE FOR IPHONE RECOVERY ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "ipad_ios=$(sw_vers -productVersion 2>/dev/null)"

echo '--- available network tools ---'
for x in ifconfig ipconfig scutil route netstat arp ping nc ssh ssh-keyscan dns-sd dscacheutil; do
  printf '%s=' "$x"; command -v "$x" 2>/dev/null || echo missing
done

echo '--- interface / routing state ---'
ifconfig 2>&1 | sed -n '1,220p' || true
ipconfig getifaddr en0 2>&1 || true
scutil --nwi 2>&1 | sed -n '1,180p' || true
route -n get default 2>&1 | sed -n '1,120p' || true
netstat -rn 2>&1 | sed -n '1,180p' || true
arp -a 2>&1 | sed -n '1,220p' || true

echo '--- hostname probes ---'
for host in iphone.local iPhone.local iphone; do
  echo "### host=$host"
  ping -c 1 -W 1000 "$host" 2>&1 | sed -n '1,40p' || true
  nc -z -w 3 "$host" 22 2>&1; echo "nc22_rc=$?"
  ssh-keyscan -T 4 -p 22 "$host" 2>&1 | sed -n '1,30p' || true
done

echo '--- Bonjour SSH browse (short) ---'
if command -v dns-sd >/dev/null 2>&1; then
  dns-sd -B _ssh._tcp local >/tmp/ssh-browse.txt 2>&1 &
  P=$!
  sleep 5
  kill "$P" 2>/dev/null || true
  cat /tmp/ssh-browse.txt | sed -n '1,120p'
fi

echo 'IPAD_LAN_PROBE_COMPLETE=true'
exit 0
