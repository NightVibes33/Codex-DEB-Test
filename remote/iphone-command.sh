#!/bin/sh
set +e

export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

section() {
  echo
  echo "===== $1 ====="
}

have() {
  command -v "$1" >/dev/null 2>&1
}

echo '=== IPHONE BATTERY DRAIN FORENSICS ==='
echo "captured_at=$(date 2>/dev/null || true)"
echo "whoami=$(whoami 2>/dev/null || true)"
echo "id=$(id 2>/dev/null || true)"
echo "hostname=$(hostname 2>/dev/null || true)"

section 'SYSTEM / BOOT'
uname -a 2>/dev/null || true
sw_vers 2>/dev/null || true
for key in hw.machine hw.model kern.osversion kern.boottime vm.loadavg kern.memorystatus_level; do
  value="$(sysctl -n "$key" 2>/dev/null || true)"
  [ -n "$value" ] && echo "$key=$value"
done
uptime 2>/dev/null || true

section 'JAILBREAK / CORE PACKAGES'
for p in /var/jb /var/jb/usr/bin /var/jb/bin /var/jb/usr/sbin /var/jb/Library/MobileSubstrate/DynamicLibraries; do
  [ -e "$p" ] && echo "present=$p"
done
if have dpkg-query; then
  dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | grep -Ei 'dopamine|ellekit|substrate|substitute|libhooker|openssh|sudo|battery|power|cocoatop|icleaner|daemon|tweak' | sort | head -n 300
fi

section 'TWEAK INJECTION INVENTORY'
for d in /var/jb/Library/MobileSubstrate/DynamicLibraries /Library/MobileSubstrate/DynamicLibraries; do
  if [ -d "$d" ]; then
    echo "directory=$d"
    ls -lat "$d" 2>/dev/null | head -n 160
  fi
done

section 'BATTERY / POWER TELEMETRY'
if have ioreg; then
  echo '-- AppleSmartBattery --'
  ioreg -r -c AppleSmartBattery -l 2>/dev/null | grep -Ei 'AppleRaw|CycleCount|CurrentCapacity|MaxCapacity|DesignCapacity|NominalChargeCapacity|Voltage|Amperage|InstantAmperage|Temperature|BatteryHealth|FullyCharged|ExternalConnected|IsCharging|TimeRemaining' | head -n 250 || true
  echo '-- registry battery-like keys --'
  ioreg -w0 -l 2>/dev/null | grep -Ei 'AppleRaw(Max|Current)Capacity|CycleCount|DesignCapacity|NominalChargeCapacity|InstantAmperage|BatteryHealth|Voltage|Temperature' | head -n 250 || true
else
  echo 'ioreg=not_available'
fi

for f in \
  /var/mobile/Library/Preferences/com.apple.powerlog.plist \
  /var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL \
  /var/mobile/Library/BatteryLife/Archives \
  /var/db/Battery; do
  if [ -e "$f" ]; then
    echo "power_path=$f"
    ls -lah "$f" 2>/dev/null | head -n 80
  fi
done

if have plutil && [ -f /var/mobile/Library/Preferences/com.apple.powerlog.plist ]; then
  echo '-- powerlog plist excerpt --'
  plutil -p /var/mobile/Library/Preferences/com.apple.powerlog.plist 2>/dev/null | head -n 250 || true
fi

if have sqlite3 && [ -f /var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL ]; then
  echo '-- powerlog database tables --'
  sqlite3 /var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL '.tables' 2>/dev/null | head -n 80 || true
fi

section 'CPU / MEMORY SNAPSHOT 1'
if have top; then
  top -l 1 -n 50 -o cpu 2>/dev/null | head -n 180 || top -l 1 2>/dev/null | head -n 180 || true
fi
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | head -n 220 || ps -A 2>/dev/null | head -n 220 || true

section 'POWER-RELEVANT PROCESSES'
ps ax 2>/dev/null | grep -Ei 'SpringBoard|backboardd|powerd|thermalmonitord|mediaserverd|mediaremoted|locationd|bluetoothd|wifid|runningboardd|symptomsd|analyticsd|aggregated|installd|mobileassetd|nsurlsessiond|cloudd|photolibraryd|photoanalysisd|searchd|spotlight|siriknowledged|jetsam|ReportCrash|CrashReporter|ElleKit|Substrate|Substitute|libhooker|Tweak' | grep -v grep || true

section 'LAUNCHD / CRASH-LOOP CLUES'
if have launchctl; then
  launchctl list 2>/dev/null | head -n 1200 || true
fi

section 'RECENT CRASH / JETSAM / PANIC FILES'
for root in /var/mobile/Library/Logs/CrashReporter /Library/Logs/CrashReporter; do
  if [ -d "$root" ]; then
    echo "crash_root=$root"
    find "$root" -type f -mmin -720 -print 2>/dev/null | head -n 500
    echo '-- newest crash files --'
    find "$root" -type f -mmin -720 -exec ls -lt {} + 2>/dev/null | head -n 220
    echo '-- likely repeated process names --'
    find "$root" -type f -mmin -720 -print 2>/dev/null \
      | sed 's#.*/##' \
      | sed -E 's/[-_][0-9]{4}.*$//' \
      | sort | uniq -c | sort -nr | head -n 80
  fi
done

section 'THERMAL / POWER LOG EXCERPTS'
if have log; then
  log show --last 15m --style compact 2>/dev/null \
    | grep -Ei 'thermal|powerd|battery|jetsam|watchdog|cpu|temperature|SpringBoard|backboardd|ReportCrash' \
    | tail -n 400 || true
else
  echo 'log_command=not_available'
fi

section 'NETWORK / RADIO STATE'
if have ifconfig; then
  ifconfig 2>/dev/null | head -n 220 || true
fi
if have netstat; then
  netstat -an 2>/dev/null | head -n 220 || true
fi

section 'CPU / MEMORY SNAPSHOT 2 AFTER 20S'
sleep 20
if have top; then
  top -l 1 -n 50 -o cpu 2>/dev/null | head -n 180 || top -l 1 2>/dev/null | head -n 180 || true
fi
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | head -n 220 || ps -A 2>/dev/null | head -n 220 || true

section 'FINAL BATTERY SAMPLE'
if have ioreg; then
  ioreg -r -c AppleSmartBattery -l 2>/dev/null | grep -Ei 'AppleRaw|CycleCount|CurrentCapacity|MaxCapacity|DesignCapacity|NominalChargeCapacity|Voltage|Amperage|InstantAmperage|Temperature|BatteryHealth|FullyCharged|ExternalConnected|IsCharging|TimeRemaining' | head -n 250 || true
fi

echo
echo '=== END IPHONE BATTERY DRAIN FORENSICS ==='
