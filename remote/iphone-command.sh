#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-windowfix.ipa'
SHA_FILE='/var/mobile/Media/3105-ios15-windowfix.sha256'
MARKER='/var/mobile/Media/3105-ui-ready.txt'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 VISIBLE UI PROOF ==='
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
  while [ "$pass" -lt 5 ]; do
    killall -9 3105 2>/dev/null || true
    PIDS="$(pidof 3105 2>/dev/null || true)"
    for p in $PIDS; do kill -9 "$p" 2>/dev/null || true; done
    ps ax 2>/dev/null | while read pid rest; do
      case "$rest" in *'/3105.app/3105'*) kill -9 "$pid" 2>/dev/null || true;; esac
    done
    sleep 1
    [ -z "$(find_pid)" ] && return 0
    pass=$((pass+1))
  done
  return 1
}

wait_for_ui_marker() {
  n=0
  while [ "$n" -lt 40 ]; do
    if [ -s "$MARKER" ]; then
      cat "$MARKER"
      grep -q '^UI_READY=1$' "$MARKER" || { echo UI_READY_MARKER_INVALID=1; return 1; }
      if grep -q '^phase=active$' "$MARKER" \
        && grep -q '^key=1$' "$MARKER" \
        && grep -q '^hidden=0$' "$MARKER" \
        && grep -q '^root_view_loaded=1$' "$MARKER"; then
        echo UI_ACTIVE_KEY_WINDOW=1
        return 0
      fi
    fi
    n=$((n+1))
    sleep 1
  done
  echo UI_MARKER_TIMEOUT=1
  [ -f "$MARKER" ] && cat "$MARKER"
  return 1
}

monitor_pid() {
  PID="$1"
  n=0
  while [ "$n" -lt 12 ]; do
    kill -0 "$PID" 2>/dev/null || { echo "PROCESS_DIED_CHECK=$n"; return 1; }
    n=$((n+1))
    echo "UI_PROCESS_ALIVE_$n pid=$PID"
    sleep 5
  done
  PID2="$(find_pid)"
  echo "final_pid=$PID2"
  [ "$PID2" = "$PID" ] || { echo "PID_CHANGED old=$PID new=$PID2"; return 1; }
  echo alive_after_60_seconds=1
  echo "stable_pid=$PID"
  return 0
}

[ -s "$IPA" ] || { echo IPA_MISSING=1; exit 90; }
[ -s "$SHA_FILE" ] || { echo SHA_FILE_MISSING=1; exit 91; }
EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE")"
GOT="$(hash_file "$IPA")"
echo "expected_ipa_sha=$EXPECTED"
echo "device_ipa_sha=$GOT"
[ -n "$EXPECTED" ] && [ "$GOT" = "$EXPECTED" ] || { echo IPA_HASH_MISMATCH=1; exit 92; }
echo IPA_HASH_MATCH=1

H="$(find_helper)"
echo "trollstorehelper=$H"
[ -n "$H" ] || exit 93
cleanup_3105 || true
rm -f "$MARKER" /var/mobile/Media/3105-windowfix-launch.log

"$H" install force "$IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
if [ "$IRC" -ne 0 ]; then
  "$H" install force installd "$IPA" 2>&1
  IRC=$?
  echo "install_installd_rc=$IRC"
fi
[ "$IRC" -eq 0 ] || exit 94
"$H" refresh 2>&1 || true
sleep 5

printf '\n===== REGISTRATION =====\n'
"$UICACHE" -i "$BUNDLE" 2>&1 || true
LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo "registration=$LINE"
APP="${LINE#* : }"
echo "registered_path=$APP"
[ -d "$APP" ] || exit 95

printf '\n===== INFO.PLIST =====\n'
if [ -x /usr/libexec/PlistBuddy ]; then
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>&1 || true
  /usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist" 2>&1 || true
fi

printf '\n===== ENTITLEMENTS =====\n'
if [ -x /var/jb/usr/bin/ldid ]; then
  /var/jb/usr/bin/ldid -e "$APP/3105" 2>&1 | tee /var/mobile/Media/3105-windowfix-entitlements.txt
  grep -q '<key>platform-application</key>' /var/mobile/Media/3105-windowfix-entitlements.txt || { echo PLATFORM_APPLICATION_MISSING=1; exit 96; }
  grep -q '<key>com.apple.private.MobileContainerManager.allowed</key>' /var/mobile/Media/3105-windowfix-entitlements.txt || { echo MCM_ENTITLEMENT_MISSING=1; exit 97; }
  echo REQUIRED_ENTITLEMENTS_PRESENT=1
fi

printf '\n===== CLEAN BASELINE =====\n'
cleanup_3105 || { echo CLEANUP_FAILED=1; exit 98; }
rm -f "$MARKER"
[ -z "$(find_pid)" ] || { echo STALE_PROCESS=1; exit 99; }
echo CLEAN_BASELINE=1

printf '\n===== FOREGROUND LAUNCH =====\n'
launchctl asuser 501 "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-windowfix-launch.log 2>&1
ASUSER_RC=$?
echo "asuser_rc=$ASUSER_RC"
cat /var/mobile/Media/3105-windowfix-launch.log 2>/dev/null || true

if ! wait_for_ui_marker; then
  echo '===== PROCESS STATE ON UI FAILURE ====='
  ps ax 2>/dev/null | while read pid rest; do case "$pid $rest" in *3105*) echo "PS_3105 $pid $rest";; esac; done
  echo UI_PRESENTATION_PROOF_FAILED=1
  exit 100
fi

PID="$(find_pid)"
echo "launch_pid=$PID"
[ -n "$PID" ] || { echo UI_READY_WITHOUT_PROCESS=1; exit 101; }
MARKER_PID="$(sed -n 's/^pid=//p' "$MARKER" | head -n 1)"
echo "marker_pid=$MARKER_PID"
[ "$MARKER_PID" = "$PID" ] || { echo MARKER_PID_MISMATCH=1; exit 102; }

monitor_pid "$PID" || { echo UI_PROCESS_STABILITY_FAILED=1; exit 103; }

printf '\n===== FINAL UI MARKER =====\n'
cat "$MARKER"
grep -q '^phase=active$' "$MARKER" || exit 104
grep -q '^key=1$' "$MARKER" || exit 105
grep -q '^hidden=0$' "$MARKER" || exit 106
grep -q '^root_view_loaded=1$' "$MARKER" || exit 107

echo UI_PRESENTATION_PROOF=1
echo RUNTIME_PROOF_SUCCESS=1
exit 0
