#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
FULL_IPA='/var/mobile/Media/3105-dopamine-launchable.ipa'
FULL_SHA='9944eaec3c8ab6ea17b962b89bafafd0cbeae1fe7117563bdf09cb420867a2a2'
MIN_IPA='/var/mobile/Media/3105-ios15-minent.ipa'
MIN_SHA='78bf5fc1ea3248eb3c613947e96b011845b32af5e0886319099d75a6d2c7c541'

echo '=== 3105 IOS15 MOBILE-SPRINGBOARD PROOF ==='
echo "device_time=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "uid=$(id -u 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file() {
  f="$1"
  if [ ! -f "$f" ]; then echo missing; return; fi
  if command -v sha256sum >/dev/null 2>&1; then
    set -- $(sha256sum "$f" 2>/dev/null); echo "$1"
  else
    set -- $(shasum -a 256 "$f" 2>/dev/null); echo "$1"
  fi
}

find_helper() {
  for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  for p in /var/containers/Bundle/Application/*/*.app/trollstorehelper; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
}

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

printf '\n===== PAYLOADS ON DEVICE =====\n'
for f in "$FULL_IPA" "$MIN_IPA"; do
  echo "file=$f"
  ls -l "$f" 2>/dev/null || true
  echo "sha256=$(hash_file "$f")"
done

# Restore the known full-entitlement compatibility build when its exact bytes are still present.
GOT_FULL="$(hash_file "$FULL_IPA")"
H="$(find_helper)"
echo "trollstorehelper=$H"
if [ "$GOT_FULL" = "$FULL_SHA" ] && [ -n "$H" ]; then
  echo FULL_IPA_HASH_MATCH=1
  killall 3105 2>/dev/null || true
  sleep 2
  "$H" install force "$FULL_IPA" 2>&1
  INSTALL_RC=$?
  echo "full_install_rc=$INSTALL_RC"
  if [ "$INSTALL_RC" -ne 0 ]; then
    "$H" install force installd "$FULL_IPA" 2>&1
    echo "full_install_installd_rc=$?"
  fi
  "$H" refresh 2>&1 || true
  sleep 5
else
  echo FULL_IPA_RESTORE_SKIPPED=1
fi

printf '\n===== LAUNCHSERVICES REGISTRATION =====\n'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen
"$UICACHE" -i "$BUNDLE" 2>&1 || true
LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo "registration=$LINE"
APP="${LINE#* : }"
echo "registered_path=$APP"
if [ -d "$APP" ]; then
  echo REGISTERED_PATH_EXISTS=1
else
  echo REGISTERED_PATH_EXISTS=0
fi

printf '\n===== INFO.PLIST =====\n'
if [ -n "$APP" ] && [ -f "$APP/Info.plist" ]; then
  plutil -p "$APP/Info.plist" 2>&1 || strings "$APP/Info.plist" 2>/dev/null | head -n 200 || true
fi

printf '\n===== ENTITLEMENTS =====\n'
LDID=''
for p in /var/jb/usr/bin/ldid /usr/bin/ldid /var/containers/Bundle/Application/*/TrollStore.app/ldid; do
  [ -x "$p" ] && { LDID="$p"; break; }
done
echo "ldid=$LDID"
if [ -n "$LDID" ] && [ -n "$APP" ] && [ -x "$APP/3105" ]; then
  "$LDID" -e "$APP/3105" 2>&1 || true
fi

killall 3105 2>/dev/null || true
sleep 2

printf '\n===== LAUNCH AS MOBILE / UID 501 =====\n'
MOBILE_RUN=''
if command -v sudo >/dev/null 2>&1; then
  MOBILE_RUN='sudo -u mobile'
elif command -v su >/dev/null 2>&1; then
  MOBILE_RUN='su mobile -c'
fi
echo "mobile_runner=$MOBILE_RUN"

PID=''
if [ "$MOBILE_RUN" = 'sudo -u mobile' ]; then
  sudo -u mobile "$UIOPEN" --bundleid "$BUNDLE" 2>&1
  echo "mobile_bundle_uiopen_rc=$?"
  PID="$(wait_pid)"
  if [ -z "$PID" ] && [ -n "$APP" ]; then
    echo MOBILE_BUNDLE_LAUNCH_NO_PID=1
    sudo -u mobile "$UIOPEN" --path "$APP" 2>&1
    echo "mobile_path_uiopen_rc=$?"
    PID="$(wait_pid)"
  fi
elif [ "$MOBILE_RUN" = 'su mobile -c' ]; then
  su mobile -c "$UIOPEN --bundleid $BUNDLE" 2>&1
  echo "mobile_bundle_uiopen_rc=$?"
  PID="$(wait_pid)"
  if [ -z "$PID" ] && [ -n "$APP" ]; then
    su mobile -c "$UIOPEN --path '$APP'" 2>&1
    echo "mobile_path_uiopen_rc=$?"
    PID="$(wait_pid)"
  fi
else
  echo NO_MOBILE_USER_RUNNER=1
fi

if [ -n "$PID" ]; then
  echo "launch_pid=$PID"
  n=0
  while [ "$n" -lt 18 ]; do
    kill -0 "$PID" 2>/dev/null || { echo "PROCESS_DIED_CHECK=$n"; exit 55; }
    n=$((n+1))
    echo "ALIVE_$n pid=$PID"
    sleep 5
  done
  PID2="$(find_pid)"
  echo "final_pid=$PID2"
  if [ "$PID2" = "$PID" ]; then
    echo alive_after_90_seconds=1
    echo "stable_pid=$PID"
    echo RUNTIME_PROOF_SUCCESS=1
    exit 0
  fi
  echo "PID_CHANGED old=$PID new=$PID2"
  exit 56
fi

echo NO_PROCESS_AFTER_MOBILE_SESSION_LAUNCH=1

printf '\n===== MOBILE LAUNCHCTL STATE =====\n'
if command -v sudo >/dev/null 2>&1; then
  sudo -u mobile launchctl print gui/501 2>&1 | grep -Ei '3105|threeoneosfive|nightvibes|F6556AA2' || true
fi

printf '\n===== DIRECT EXECUTION CONTROLS =====\n'
if [ -n "$APP" ] && [ -x "$APP/3105" ]; then
  "$APP/3105" >/var/mobile/Media/3105-direct-root.log 2>&1 &
  RP=$!
  echo "root_direct_pid=$RP"
  sleep 5
  if kill -0 "$RP" 2>/dev/null; then
    echo ROOT_DIRECT_ALIVE_AFTER_5S=1
    kill "$RP" 2>/dev/null || true
  else
    echo ROOT_DIRECT_ALIVE_AFTER_5S=0
  fi
  cat /var/mobile/Media/3105-direct-root.log 2>/dev/null || true

  if command -v sudo >/dev/null 2>&1; then
    sudo -u mobile "$APP/3105" >/var/mobile/Media/3105-direct-mobile.log 2>&1 &
    MP=$!
    echo "mobile_direct_wrapper_pid=$MP"
    sleep 5
    if kill -0 "$MP" 2>/dev/null; then
      echo MOBILE_DIRECT_ALIVE_AFTER_5S=1
      kill "$MP" 2>/dev/null || true
    else
      echo MOBILE_DIRECT_ALIVE_AFTER_5S=0
    fi
    cat /var/mobile/Media/3105-direct-mobile.log 2>/dev/null || true
  fi
fi

printf '\n===== PROCESS / CRASH / SYSTEM DIAGNOSTICS =====\n'
ps ax 2>/dev/null | while read pid rest; do case "$pid $rest" in *3105*|*threeoneosfive*|*nightvibes*) echo "PS_MATCH $pid $rest";; esac; done
ls -lT /var/mobile/Library/Logs/CrashReporter/3105-*.ips 2>/dev/null || true
if [ -x /usr/bin/log ]; then
  /usr/bin/log show --last 6m --style compact --predicate 'process == "SpringBoard" OR process == "runningboardd" OR process == "lsd" OR process == "amfid"' 2>&1 \
    | grep -Ei '3105|threeoneosfive|nightvibes|launch|denied|invalid|entitlement|signature|F6556AA2' \
    | tail -n 600 || true
fi

echo MOBILE_SESSION_PROOF_FAILED=1
exit 54
