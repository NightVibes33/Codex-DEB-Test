#!/bin/sh
set +e

echo '=== IPHONE SSH DIAGNOSTIC ==='
echo "time=$(date 2>/dev/null || true)"
echo "whoami=$(whoami 2>/dev/null || true)"
echo "uid=$(id 2>/dev/null || true)"
echo "hostname=$(hostname 2>/dev/null || true)"

echo
echo '--- system ---'
uname -a 2>/dev/null || true
sw_vers 2>/dev/null || true
sysctl -n hw.machine 2>/dev/null | sed 's/^/hw.machine=/'
sysctl -n hw.model 2>/dev/null | sed 's/^/hw.model=/'
sysctl -n kern.osversion 2>/dev/null | sed 's/^/kern.osversion=/'
sysctl -n kern.boottime 2>/dev/null | sed 's/^/kern.boottime=/'
uptime 2>/dev/null || true

echo
echo '--- jailbreak ---'
for p in /var/jb /var/jb/usr/bin /var/jb/bin /var/jb/usr/sbin; do
  if [ -e "$p" ]; then echo "present=$p"; fi
done
if command -v dpkg >/dev/null 2>&1; then
  dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | grep -Ei 'dopamine|ellekit|openssh|battery|cocoatop|power' | head -n 80 || true
elif [ -x /var/jb/usr/bin/dpkg-query ]; then
  /var/jb/usr/bin/dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | grep -Ei 'dopamine|ellekit|openssh|battery|cocoatop|power' | head -n 80 || true
fi

echo
echo '--- battery / power ---'
if command -v ioreg >/dev/null 2>&1; then
  ioreg -r -c AppleSmartBattery -l 2>/dev/null | grep -Ei 'CycleCount|CurrentCapacity|MaxCapacity|DesignCapacity|Voltage|Amperage|InstantAmperage|Temperature|BatteryHealth|FullyCharged|ExternalConnected|IsCharging' || true
fi
if [ -x /usr/bin/ioreg ]; then
  /usr/bin/ioreg -r -c AppleSmartBattery -l 2>/dev/null | grep -Ei 'CycleCount|CurrentCapacity|MaxCapacity|DesignCapacity|Voltage|Amperage|InstantAmperage|Temperature|BatteryHealth|FullyCharged|ExternalConnected|IsCharging' || true
fi

for f in \
  /var/mobile/Library/Preferences/com.apple.powerlog.plist \
  /var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL; do
  [ -e "$f" ] && echo "power_file_present=$f"
done

echo
echo '--- thermal / load ---'
sysctl -n vm.loadavg 2>/dev/null | sed 's/^/loadavg=/'
ps ax -o pid,%cpu,%mem,etime,comm 2>/dev/null | head -n 60 || \
ps -A 2>/dev/null | head -n 60 || true

echo
echo '--- suspicious processes ---'
ps ax 2>/dev/null | grep -Ei 'SpringBoard|backboardd|powerd|thermalmonitord|mediaserverd|locationd|bluetoothd|wifid|runningboardd|jetsam|crash|ellekit|substrate|tweak' | grep -v grep || true

echo
echo '=== END DIAGNOSTIC ==='
