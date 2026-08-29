#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
UIOPEN=/var/jb/usr/bin/uiopen
UICACHE=/var/jb/usr/bin/uicache

echo '=== 3105 IOS15 POST-LAUNCH CRASH POSTMORTEM ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

find_pid() {
  if command -v pidof >/dev/null 2>&1; then
    P="$(pidof 3105 2>/dev/null || true)"
    set -- $P
    [ -n "${1:-}" ] && { echo "$1"; return; }
  fi
  ps ax 2>/dev/null | while read pid rest; do
    case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac
  done
}

wait_pid() {
  n=0
  while [ "$n" -lt 20 ]; do
    P="$(find_pid)"
    [ -n "$P" ] && { echo "$P"; return 0; }
    n=$((n+1))
    sleep 1
  done
  return 1
}

LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo "registration=$LINE"
APP="${LINE#* : }"
echo "registered_path=$APP"
[ -d "$APP" ] || { echo APP_PATH_MISSING=1; exit 60; }
[ -x "$APP/3105" ] || { echo APP_BINARY_MISSING=1; exit 61; }

printf '\n===== INSTALLED ENTITLEMENTS =====\n'
if [ -x /var/jb/usr/bin/ldid ]; then /var/jb/usr/bin/ldid -e "$APP/3105" 2>&1 || true; fi

printf '\n===== CRASH REPORTS BEFORE LAUNCH =====\n'
ls -lT /var/mobile/Library/Logs/CrashReporter/3105-*.ips 2>/dev/null | tail -n 20 || true

killall 3105 2>/dev/null || true
sleep 2

START_EPOCH="$(date +%s 2>/dev/null || echo 0)"
START_TEXT="$(date 2>/dev/null)"
echo "launch_start_epoch=$START_EPOCH"
echo "launch_start=$START_TEXT"

printf '\n===== SPRINGBOARD LAUNCH AS MOBILE =====\n'
sudo -u mobile "$UIOPEN" --bundleid "$BUNDLE" 2>&1
echo "uiopen_rc=$?"
PID="$(wait_pid)"
if [ -z "$PID" ]; then
  echo NO_PID_AFTER_LAUNCH=1
else
  echo "launch_pid=$PID"
  SECOND=0
  DIED=0
  while [ "$SECOND" -lt 30 ]; do
    if kill -0 "$PID" 2>/dev/null; then
      echo "ALIVE_SECOND_$SECOND pid=$PID"
    else
      echo "DIED_AT_SECOND=$SECOND pid=$PID"
      DIED=1
      break
    fi
    SECOND=$((SECOND+1))
    sleep 1
  done
  if [ "$DIED" -eq 0 ]; then
    echo ALIVE_AFTER_30_SECONDS=1
  fi
fi

sleep 3
printf '\n===== CRASH REPORTS AFTER LAUNCH =====\n'
ls -lT /var/mobile/Library/Logs/CrashReporter/3105-*.ips 2>/dev/null | tail -n 30 || true

LATEST=''
for f in /var/mobile/Library/Logs/CrashReporter/3105-*.ips; do
  [ -f "$f" ] || continue
  LATEST="$f"
done
if [ -n "$LATEST" ]; then
  echo "latest_crash=$LATEST"
  echo '----- LATEST CRASH HEAD -----'
  head -n 260 "$LATEST" 2>/dev/null || cat "$LATEST" 2>/dev/null | head -n 260 || true
  echo '----- CRASH KEY LINES -----'
  grep -Ei 'exception|termination|reason|signal|dyld|library|symbol|abort|namespace|code|culprit|fault|triggered|thread|bug_type|procName|bundleInfo' "$LATEST" 2>/dev/null | head -n 220 || true
fi

printf '\n===== RUNNINGBOARD / SPRINGBOARD / AMFID LOGS =====\n'
if [ -x /usr/bin/log ]; then
  /usr/bin/log show --last 4m --style compact \
    --predicate 'process == "SpringBoard" OR process == "runningboardd" OR process == "lsd" OR process == "amfid" OR process == "3105"' 2>&1 \
    | grep -Ei '3105|threeoneosfive|nightvibes|F6556AA2|launch|terminate|termination|kill|invalid|denied|entitlement|signature|dyld|crash|jetsam|watchdog|scene' \
    | tail -n 700 || true
else
  echo LOG_TOOL_NOT_AVAILABLE=1
fi

printf '\n===== ROOT DIRECT CONTROL =====\n'
"$APP/3105" >/var/mobile/Media/3105-direct-root.log 2>&1 &
RP=$!
echo "root_direct_pid=$RP"
n=0
while [ "$n" -lt 12 ]; do
  if kill -0 "$RP" 2>/dev/null; then
    echo "ROOT_DIRECT_ALIVE_SECOND_$n=1"
  else
    echo "ROOT_DIRECT_DIED_SECOND=$n"
    break
  fi
  n=$((n+1))
  sleep 1
done
kill "$RP" 2>/dev/null || true
cat /var/mobile/Media/3105-direct-root.log 2>/dev/null | head -n 180 || true

printf '\n===== MOBILE DIRECT CONTROL =====\n'
sudo -u mobile "$APP/3105" >/var/mobile/Media/3105-direct-mobile.log 2>&1 &
MP=$!
echo "mobile_direct_wrapper_pid=$MP"
n=0
while [ "$n" -lt 12 ]; do
  if kill -0 "$MP" 2>/dev/null; then
    echo "MOBILE_DIRECT_ALIVE_SECOND_$n=1"
  else
    echo "MOBILE_DIRECT_DIED_SECOND=$n"
    break
  fi
  n=$((n+1))
  sleep 1
done
kill "$MP" 2>/dev/null || true
cat /var/mobile/Media/3105-direct-mobile.log 2>/dev/null | head -n 180 || true

printf '\n===== FINAL PROCESS STATE =====\n'
ps ax 2>/dev/null | while read pid rest; do case "$pid $rest" in *3105*|*threeoneosfive*|*nightvibes*) echo "PS_MATCH $pid $rest";; esac; done

echo POSTMORTEM_COMPLETE=1
exit 0
