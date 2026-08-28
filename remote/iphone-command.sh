#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
section(){ echo; echo "===== $1 ====="; }

echo '=== IPHONE BATTERY DRAIN OWNER TRIAGE ==='
echo "captured_at=$(date 2>/dev/null)"

section 'LIVE BATTERY GAUGE'
if command -v ioreg >/dev/null 2>&1; then
  ioreg -l 2>/dev/null | grep -E '"(AppleRawCurrentCapacity|AppleRawMaxCapacity|CurrentCapacity|MaxCapacity|DesignCapacity|NominalChargeCapacity|CycleCount|Voltage|InstantAmperage|Amperage|Temperature|StateOfCharge|BatteryHealthMetric|WeightedRa|ChemicalWeightedRa|RSS|ResScale|BatteryShutdownReason|BatteryData)"' | head -n 100
fi

section 'TWEAK FILES + PACKAGE OWNERS'
D=/var/jb/usr/lib/TweakInject
if [ -d "$D" ]; then
  find "$D" -maxdepth 1 -type f -print 2>/dev/null | sort | while IFS= read -r f; do
    echo "file=$f"
    if command -v dpkg-query >/dev/null 2>&1; then
      owner="$(dpkg-query -S "$f" 2>/dev/null | head -n 1)"
      [ -n "$owner" ] && echo "owner=$owner" || echo 'owner=UNOWNED'
    fi
    case "$f" in
      *.plist)
        echo 'plist_strings:'
        strings "$f" 2>/dev/null | head -n 40
        ;;
    esac
  done
fi

section 'SUSPECT PACKAGE DETAILS'
if command -v dpkg-query >/dev/null 2>&1; then
  for pkg in xyz.cypwn.startupoptimizations xyz.cypwn.stopautolaunchapps xyz.cypwn.systemmemoryresetfix xyz.cypwn.appstoretrollern xyz.cypwn.appsyncunified com.rpetrich.rocketbootstrap; do
    dpkg-query -W -f='package=${Package}\nversion=${Version}\nstatus=${db:Status-Abbrev}\ndescription=${Description}\n\n' "$pkg" 2>/dev/null
  done
fi

section 'THIRD PARTY LAUNCH DAEMONS'
for f in /var/jb/Library/LaunchDaemons/*.plist; do
  [ -f "$f" ] || continue
  echo "daemon=$f"
  if command -v dpkg-query >/dev/null 2>&1; then
    owner="$(dpkg-query -S "$f" 2>/dev/null | head -n 1)"; [ -n "$owner" ] && echo "owner=$owner" || echo 'owner=UNOWNED'
  fi
  echo 'plist_strings:'
  strings "$f" 2>/dev/null | head -n 80
  echo
 done

section 'LAUNCHCTL FAILURES / RESTART CANDIDATES'
launchctl list 2>/dev/null | grep -Ev '^PID|com\.apple\.' | head -n 150
launchctl list 2>/dev/null | awk 'NR>1 && $2 != 0 {print}' | head -n 150

section 'CURRENT CPU TOP'
ps ax -o pid,ppid,%cpu,%mem,etime,state,comm 2>/dev/null | (head -n 1; tail -n +2 | sort -k3 -nr | head -n 35)

section 'RESOURCE REPORT COUNTS'
CR=/var/mobile/Library/Logs/CrashReporter
for pat in 'IPNExtension.wakeups_resource' 'healthd.diskwrites_resource' 'LowBatteryLog' 'routined' 'cloudd' 'JetsamEvent'; do
  count="$(find "$CR" -maxdepth 2 -type f -name "${pat}*.ips" 2>/dev/null | wc -l | tr -d ' ')"
  echo "$pat=$count"
done

section 'TAILSCALE RESOURCE VIOLATION SUMMARY'
f="$(find "$CR" -maxdepth 2 -type f -name 'IPNExtension.wakeups_resource*.ips' 2>/dev/null | sort | tail -n 1)"
[ -f "$f" ] && grep -E 'Wakeups:|Wakeups caused:|Duration:|Advisory levels:|Power Source:' "$f" 2>/dev/null | head -n 30

section 'LOW BATTERY DROOP SUMMARY'
f="$(find "$CR" -maxdepth 2 -type f -name 'LowBatteryLog*.ips' 2>/dev/null | sort | tail -n 1)"
[ -f "$f" ] && grep -E 'Voltage:|Voltage Droop|PreventUserIdle|timestamp' "$f" 2>/dev/null | head -n 40

echo '=== END OWNER TRIAGE ==='
