#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }
have(){ command -v "$1" >/dev/null 2>&1; }
battery_sample(){
  tag="$1"
  echo "--- battery_sample=$tag time=$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null) ---"
  if have ioreg; then
    ioreg -r -c AppleSmartBattery -l 2>/dev/null | grep -E '"(AppleRawCurrentCapacity|AppleRawMaxCapacity|CurrentCapacity|MaxCapacity|DesignCapacity|NominalChargeCapacity|CycleCount|Voltage|InstantAmperage|Amperage|Temperature|IsCharging|ExternalConnected|FullyCharged|BatteryHealthMetric|BatteryHealth|StateOfCharge|Qmax|WeightedRa|RSS|ResScale|ChargerData|AdapterDetails|BatteryShutdownReason)"' | head -n 80
  else
    echo 'ioreg=not_available'
  fi
}
cpu_sample(){
  tag="$1"
  echo "--- cpu_sample=$tag time=$(date '+%H:%M:%S' 2>/dev/null) ---"
  ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | (head -n 1; tail -n +2 | sort -k3 -nr | head -n 30) || true
}

echo '=== IPHONE DEEP BATTERY / POWER FORENSICS ==='
echo "captured_at=$(date 2>/dev/null || true)"
echo "whoami=$(whoami 2>/dev/null || true)"
echo "id=$(id 2>/dev/null || true)"

section 'SYSTEM / BOOT'
uname -a 2>/dev/null || true
sw_vers 2>/dev/null || true
for key in hw.machine hw.model kern.osversion kern.boottime vm.loadavg kern.memorystatus_level; do
  value="$(sysctl -n "$key" 2>/dev/null || true)"; [ -n "$value" ] && echo "$key=$value"
done
uptime 2>/dev/null || true

section 'JAILBREAK / PACKAGE INVENTORY'
for p in /var/jb /var/jb/usr/bin /var/jb/bin /var/jb/usr/sbin /var/jb/usr/lib/TweakInject /var/jb/Library/LaunchDaemons; do [ -e "$p" ] && echo "present=$p"; done
if have dpkg-query; then
  echo '-- selected packages --'
  dpkg-query -W -f='${Package}\t${Version}\t${Maintainer}\n' 2>/dev/null | grep -Ei 'dopamine|ellekit|substrate|substitute|libhooker|openssh|sudo|battery|power|cocoatop|icleaner|rocketbootstrap|tweak|theme|snowboard|crane|dynamic|statusbar|springboard|daemon' | sort | head -n 500
  echo '-- recent package install metadata --'
  ls -lat /var/jb/var/lib/dpkg/info 2>/dev/null | head -n 120 || true
fi

section 'TWEAK INJECTION INVENTORY / FILTERS'
for d in /var/jb/usr/lib/TweakInject /var/jb/Library/MobileSubstrate/DynamicLibraries /Library/MobileSubstrate/DynamicLibraries; do
  if [ -d "$d" ]; then
    echo "directory=$d"
    ls -lahT "$d" 2>/dev/null | head -n 240 || ls -lah "$d" 2>/dev/null | head -n 240
    for f in "$d"/*.plist; do
      [ -f "$f" ] || continue
      echo "--- filter=$f ---"
      if have plutil; then plutil -p "$f" 2>/dev/null | head -n 100; else cat "$f" 2>/dev/null | head -n 100; fi
    done
  fi
done

section 'JAILBREAK LAUNCH DAEMONS'
for d in /var/jb/Library/LaunchDaemons /Library/LaunchDaemons; do
  [ -d "$d" ] || continue
  echo "directory=$d"
  ls -lahT "$d" 2>/dev/null | head -n 240 || ls -lah "$d" 2>/dev/null | head -n 240
  for f in "$d"/*.plist; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in
      com.apple.*) ;;
      *) echo "--- daemon=$f ---"; if have plutil; then plutil -p "$f" 2>/dev/null | head -n 100; fi ;;
    esac
  done
done

section 'BATTERY GAUGE / HARDWARE STATE'
battery_sample baseline
if have ioreg; then
  echo '-- compact BatteryData --'
  ioreg -r -c AppleSmartBattery -l 2>/dev/null | grep -E '"BatteryData"|"BatteryShutdownReason"|"LifetimeData"|"NominalChargeCapacity"|"AppleRawMaxCapacity"|"DesignCapacity"|"CycleCount"|"Voltage"|"InstantAmperage"|"Temperature"' | head -n 160
fi

section 'POWERLOG DATABASE'
for f in /var/mobile/Library/Preferences/com.apple.powerlog.plist /var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL /var/mobile/Library/BatteryLife/Archives /var/db/Battery; do
  if [ -e "$f" ]; then echo "power_path=$f"; ls -lah "$f" 2>/dev/null | head -n 80; fi
done
if have plutil && [ -f /var/mobile/Library/Preferences/com.apple.powerlog.plist ]; then
  echo '-- powerlog preferences --'
  plutil -p /var/mobile/Library/Preferences/com.apple.powerlog.plist 2>/dev/null | head -n 260 || true
fi
if have sqlite3 && [ -f /var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL ]; then
  DB=/var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL
  echo '-- powerlog tables --'
  sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>/dev/null | head -n 300
  echo '-- battery/power related schema --'
  sqlite3 "$DB" "SELECT name, sql FROM sqlite_master WHERE type='table' AND (lower(name) LIKE '%batt%' OR lower(name) LIKE '%power%' OR lower(name) LIKE '%energy%' OR lower(name) LIKE '%thermal%' OR lower(name) LIKE '%current%' OR lower(name) LIKE '%voltage%') ORDER BY name;" 2>/dev/null | head -n 400
fi

section 'CRASH / RESOURCE REPORT DETAILS'
CR=/var/mobile/Library/Logs/CrashReporter
if [ -d "$CR" ]; then
  for pattern in 'LowBatteryLog' 'IPNExtension.wakeups_resource' 'healthd.diskwrites_resource' 'routined' 'cloudd' 'JetsamEvent'; do
    file="$(find "$CR" -maxdepth 2 -type f -name "${pattern}*.ips" -print 2>/dev/null | sort | tail -n 1)"
    [ -n "$file" ] && [ -f "$file" ] || continue
    echo "--- report=$file ---"
    grep -Ei 'timestamp|bug_type|procName|process|duration|wakeups|wakeup|cpu|energy|writes|write|battery|voltage|thermal|reason|exception|termination|jetsam|memory|resident|footprint|limit|state|count' "$file" 2>/dev/null | head -n 220
  done
fi

section 'CURRENT POWER-RELEVANT PROCESSES'
cpu_sample initial
ps ax 2>/dev/null | grep -Ei 'SpringBoard|backboardd|powerd|thermalmonitord|mediaserverd|mediaremoted|locationd|bluetoothd|wifid|runningboardd|symptomsd|analyticsd|aggregated|installd|mobileassetd|nsurlsessiond|cloudd|photoanalysisd|searchd|spotlight|siriknowledged|ReportCrash|ElleKit|Substrate|Substitute|libhooker|rocketd|Tweak|tailscale|IPNExtension|sshd' | grep -v grep || true

section '2-MINUTE LIVE DISCHARGE / CPU TRACE'
echo 'NOTE: current is raw IOKit gauge output; large unsigned values represent negative discharge current on this OS.'
i=1
while [ "$i" -le 24 ]; do
  battery_sample "trace_$i"
  case "$i" in
    1|4|8|12|16|20|24) cpu_sample "trace_$i" ;;
  esac
  [ "$i" -lt 24 ] && sleep 5
  i=$((i + 1))
done

section 'LAUNCHD NON-APPLE / FAILED SERVICES'
if have launchctl; then
  launchctl list 2>/dev/null | grep -Ev '^PID|com\.apple\.' | head -n 300 || true
  echo '-- nonzero launchctl status --'
  launchctl list 2>/dev/null | awk 'NR>1 && $2 != 0 {print}' | head -n 240 || true
fi

section 'FINAL STATE'
battery_sample final
cpu_sample final

echo
echo '=== END IPHONE DEEP BATTERY / POWER FORENSICS ==='
