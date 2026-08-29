#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-windowfix.ipa'
SHA_FILE='/var/mobile/Media/3105-ios15-windowfix.sha256'
MARKER='/var/mobile/Media/3105-ui-ready.txt'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 SPRINGBOARD GUI LAUNCH PROOF ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file() {
  f="$1"
  [ -f "$f" ] || { echo missing; return; }
  if command -v sha256sum >/dev/null 2>&1; then
    set -- $(sha256sum "$f" 2>/dev/null)
  else
    set -- $(shasum -a 256 "$f" 2>/dev/null)
  fi
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
  P="$(pidof 3105 2>/dev/null || true)"
  set -- $P
  [ -n "${1:-}" ] && { echo "$1"; return; }
  ps ax 2>/dev/null | while read pid rest; do
    case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac
  done
}

cleanup_3105() {
  killall -9 3105 2>/dev/null || true
  for p in $(pidof 3105 2>/dev/null || true); do kill -9 "$p" 2>/dev/null || true; done
  sleep 2
}

wait_for_marker() {
  label="$1"
  n=0
  while [ "$n" -lt 25 ]; do
    if [ -s "$MARKER" ]; then
      echo "${label}_UI_MARKER=1"
      cat "$MARKER"
      P="$(find_pid)"
      echo "${label}_PID=$P"
      return 0
    fi
    P="$(find_pid)"
    [ -n "$P" ] && echo "${label}_TRANSIENT_PID_${n}=$P"
    n=$((n+1))
    sleep 1
  done
  echo "${label}_UI_MARKER=0"
  return 1
}

print_recent_crashes() {
  echo '===== RECENT 3105 CRASH REPORTS ====='
  for d in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/DiagnosticLogs /Library/Logs/CrashReporter; do
    [ -d "$d" ] || continue
    ls -1t "$d"/*3105* 2>/dev/null | head -n 4 | while read f; do
      echo "CRASH_FILE=$f"
      sed -n '1,220p' "$f" 2>/dev/null || true
    done
  done
}

EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE" 2>/dev/null)"
GOT="$(hash_file "$IPA")"
echo "expected_ipa_sha=$EXPECTED"
echo "device_ipa_sha=$GOT"
[ -n "$EXPECTED" ] && [ "$GOT" = "$EXPECTED" ] || exit 90

H="$(find_helper)"
echo "trollstorehelper=$H"
[ -n "$H" ] || exit 91

cleanup_3105
rm -f "$MARKER" /var/mobile/Media/3105-uiopen-*.log
"$H" install force "$IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
[ "$IRC" -eq 0 ] || exit 92
"$H" refresh 2>&1 || true
sleep 5

LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
APP="${LINE#* : }"
echo "registration=$LINE"
echo "registered_path=$APP"
[ -d "$APP" ] || exit 93

SPIDS="$(pidof SpringBoard 2>/dev/null || true)"
set -- $SPIDS
SBPID="${1:-}"
echo "springboard_pids=$SPIDS"
echo "springboard_pid=$SBPID"
[ -n "$SBPID" ] || { echo SPRINGBOARD_PID_MISSING=1; exit 94; }

printf '\n===== UIOPEN CAPABILITIES =====\n'
"$UIOPEN" --help 2>&1 || true

printf '\n===== SPRINGBOARD BSEXEC BUNDLE-ID LAUNCH =====\n'
cleanup_3105
rm -f "$MARKER"
launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-uiopen-bsexec-bundle.log 2>&1
BRC=$?
echo "bsexec_bundle_rc=$BRC"
cat /var/mobile/Media/3105-uiopen-bsexec-bundle.log 2>/dev/null || true
if wait_for_marker BSEXEC_BUNDLE; then
  P="$(find_pid)"
  sleep 15
  P2="$(find_pid)"
  echo "stable_pid_before=$P"
  echo "stable_pid_after_15s=$P2"
  [ -n "$P2" ] && [ "$P" = "$P2" ] && echo UI_PROCESS_STABLE=1 || echo UI_PROCESS_STABLE=0
  echo GUI_LAUNCH_PROOF_SUCCESS=1
  exit 0
fi

printf '\n===== SPRINGBOARD BSEXEC URL-SCHEME LAUNCH =====\n'
cleanup_3105
rm -f "$MARKER"
launchctl bsexec "$SBPID" "$UIOPEN" --url 'threeoneosfive://' > /var/mobile/Media/3105-uiopen-bsexec-url.log 2>&1
URC=$?
echo "bsexec_url_rc=$URC"
cat /var/mobile/Media/3105-uiopen-bsexec-url.log 2>/dev/null || true
if wait_for_marker BSEXEC_URL; then
  P="$(find_pid)"
  sleep 15
  P2="$(find_pid)"
  echo "stable_pid_before=$P"
  echo "stable_pid_after_15s=$P2"
  [ -n "$P2" ] && [ "$P" = "$P2" ] && echo UI_PROCESS_STABLE=1 || echo UI_PROCESS_STABLE=0
  echo GUI_LAUNCH_PROOF_SUCCESS=1
  exit 0
fi

printf '\n===== MOBILE UIOPEN BUNDLE-ID LAUNCH =====\n'
cleanup_3105
rm -f "$MARKER"
sudo -u mobile "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-uiopen-mobile.log 2>&1
MRC=$?
echo "mobile_uiopen_rc=$MRC"
cat /var/mobile/Media/3105-uiopen-mobile.log 2>/dev/null || true
if wait_for_marker MOBILE_UIOPEN; then
  echo GUI_LAUNCH_PROOF_SUCCESS=1
  exit 0
fi

printf '\n===== DIRECT EXECUTION DIAGNOSTIC =====\n'
cleanup_3105
rm -f "$MARKER" /var/mobile/Media/3105-direct-mobile.log
sudo -u mobile "$APP/3105" > /var/mobile/Media/3105-direct-mobile.log 2>&1 &
WRAPPER=$!
echo "direct_wrapper_pid=$WRAPPER"
sleep 8
P="$(find_pid)"
echo "direct_pid=$P"
cat /var/mobile/Media/3105-direct-mobile.log 2>/dev/null | head -n 220 || true
[ -s "$MARKER" ] && { echo DIRECT_UI_MARKER=1; cat "$MARKER"; } || echo DIRECT_UI_MARKER=0

print_recent_crashes
printf '\n===== SYSTEM TAIL =====\n'
dmesg 2>/dev/null | tail -n 120 || true

echo GUI_LAUNCH_PROOF_SUCCESS=0
exit 0
