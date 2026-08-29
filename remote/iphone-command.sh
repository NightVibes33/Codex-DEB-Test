#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
FULL_IPA='/var/mobile/Media/3105-dopamine-launchable.ipa'
FULL_SHA='9944eaec3c8ab6ea17b962b89bafafd0cbeae1fe7117563bdf09cb420867a2a2'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 SPRINGBOARD BOOTSTRAP PROOF ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file() {
  f="$1"
  [ -f "$f" ] || { echo missing; return; }
  if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi
  echo "$1"
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
  ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done
}

cleanup_3105() {
  pass=0
  while [ "$pass" -lt 4 ]; do
    killall -9 3105 2>/dev/null || true
    PIDS="$(pidof 3105 2>/dev/null || true)"
    for p in $PIDS; do kill -9 "$p" 2>/dev/null || true; done
    ps ax 2>/dev/null | while read pid rest; do
      case "$rest" in
        *'/3105.app/3105'*) kill -9 "$pid" 2>/dev/null || true ;;
      esac
    done
    sleep 1
    [ -z "$(find_pid)" ] && return 0
    pass=$((pass+1))
  done
  echo '=== STALE PROCESS LIST ==='
  ps ax 2>/dev/null | while read pid rest; do
    case "$pid $rest" in *3105*) echo "STALE_PS $pid $rest";; esac
  done
  return 1
}

find_springboard_pid() {
  if command -v pidof >/dev/null 2>&1; then
    P="$(pidof SpringBoard 2>/dev/null || true)"; set -- $P; [ -n "${1:-}" ] && { echo "$1"; return; }
  fi
  ps ax 2>/dev/null | while read pid rest; do case "$rest" in *SpringBoard*) echo "$pid"; break;; esac; done
}

wait_pid() {
  limit="${1:-12}"
  n=0
  while [ "$n" -lt "$limit" ]; do
    P="$(find_pid)"
    [ -n "$P" ] && { echo "$P"; return 0; }
    n=$((n+1)); sleep 1
  done
  return 1
}

monitor_90() {
  PID="$1"
  LABEL="$2"
  echo "${LABEL}_launch_pid=$PID"
  n=0
  while [ "$n" -lt 18 ]; do
    if ! kill -0 "$PID" 2>/dev/null; then
      echo "${LABEL}_PROCESS_DIED_CHECK=$n"
      return 1
    fi
    n=$((n+1))
    echo "${LABEL}_ALIVE_$n pid=$PID"
    sleep 5
  done
  PID2="$(find_pid)"
  echo "${LABEL}_final_pid=$PID2"
  [ "$PID2" = "$PID" ] || { echo "${LABEL}_PID_CHANGED old=$PID new=$PID2"; return 1; }
  echo alive_after_90_seconds=1
  echo "stable_pid=$PID"
  echo "launch_method=$LABEL"
  echo RUNTIME_PROOF_SUCCESS=1
  return 0
}

GOT="$(hash_file "$FULL_IPA")"
echo "full_ipa_sha=$GOT"
[ "$GOT" = "$FULL_SHA" ] || { echo FULL_IPA_HASH_MISMATCH=1; exit 80; }
echo FULL_IPA_HASH_MATCH=1

H="$(find_helper)"
echo "trollstorehelper=$H"
[ -n "$H" ] || exit 81
cleanup_3105 || true
"$H" install force "$FULL_IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
if [ "$IRC" -ne 0 ]; then "$H" install force installd "$FULL_IPA" 2>&1; IRC=$?; echo "install_installd_rc=$IRC"; fi
[ "$IRC" -eq 0 ] || exit 82
"$H" refresh 2>&1 || true
sleep 5

printf '\n===== REGISTRATION =====\n'
"$UICACHE" -i "$BUNDLE" 2>&1 || true
LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo "registration=$LINE"
APP="${LINE#* : }"
echo "registered_path=$APP"
[ -d "$APP" ] || exit 83

printf '\n===== FULL ENTITLEMENT CHECK =====\n'
if [ -x /var/jb/usr/bin/ldid ]; then
  /var/jb/usr/bin/ldid -e "$APP/3105" 2>&1 | tee /var/mobile/Media/3105-full-entitlements.txt
  grep -q '<key>platform-application</key>' /var/mobile/Media/3105-full-entitlements.txt && echo PLATFORM_APPLICATION_PRESENT=1
  grep -q '<key>com.apple.private.MobileContainerManager.allowed</key>' /var/mobile/Media/3105-full-entitlements.txt && echo MCM_ENTITLEMENT_PRESENT=1
fi

SBPID="$(find_springboard_pid)"
echo "springboard_pid=$SBPID"
launchctl print gui/501 2>&1 | grep -E 'type =|state =|SpringBoard' | head -n 40 || true

printf '\n===== CLEAN ZERO-PROCESS BASELINE =====\n'
if cleanup_3105; then
  echo CLEAN_BASELINE=1
else
  echo STALE_3105_PROCESS_REMAINS=1
  exit 84
fi
[ -z "$(find_pid)" ] || { echo ZERO_BASELINE_VERIFY_FAILED=1; exit 84; }

printf '\n===== METHOD 1: LAUNCHCTL ASUSER 501 =====\n'
launchctl asuser 501 "$UIOPEN" --bundleid "$BUNDLE" 2>&1
echo "asuser_rc=$?"
PID="$(wait_pid 12)"
if [ -n "$PID" ]; then
  if monitor_90 "$PID" ASUSER; then exit 0; fi
fi

cleanup_3105 || true

printf '\n===== METHOD 2: SPRINGBOARD BSEXEC =====\n'
if [ -n "$SBPID" ]; then
  launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" 2>&1
  echo "bsexec_rc=$?"
  PID="$(wait_pid 12)"
  if [ -n "$PID" ]; then
    if monitor_90 "$PID" BSEXEC; then exit 0; fi
  fi
else
  echo SPRINGBOARD_PID_NOT_FOUND=1
fi

cleanup_3105 || true

printf '\n===== METHOD 3: MOBILE + SPRINGBOARD BSEXEC =====\n'
if [ -n "$SBPID" ]; then
  sudo -u mobile launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" 2>&1
  echo "mobile_bsexec_rc=$?"
  PID="$(wait_pid 12)"
  if [ -n "$PID" ]; then
    if monitor_90 "$PID" MOBILE_BSEXEC; then exit 0; fi
  fi
fi

cleanup_3105 || true

printf '\n===== FAILURE CONTROL =====\n'
sudo -u mobile "$APP/3105" >/var/mobile/Media/3105-bootstrap-direct.log 2>&1 &
WP=$!
echo "direct_wrapper_pid=$WP"
sleep 12
if kill -0 "$WP" 2>/dev/null; then echo DIRECT_WRAPPER_ALIVE_AFTER_12S=1; else echo DIRECT_WRAPPER_ALIVE_AFTER_12S=0; fi
ACTUAL="$(find_pid)"
echo "direct_actual_pid=$ACTUAL"
[ -n "$ACTUAL" ] && kill -0 "$ACTUAL" 2>/dev/null && echo DIRECT_ACTUAL_ALIVE_AFTER_12S=1
cat /var/mobile/Media/3105-bootstrap-direct.log 2>/dev/null | head -n 180 || true

echo SPRINGBOARD_BOOTSTRAP_PROOF_FAILED=1
exit 85
