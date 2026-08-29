#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-windowfix.ipa'
SHA_FILE='/var/mobile/Media/3105-ios15-windowfix.sha256'
MARKER='/var/mobile/Media/3105-ui-ready.txt'
PHASE='/var/mobile/Media/3105-launch-phase.txt'
LOG='/var/mobile/Media/3105-uiopen.log'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 EARLY WINDOW PROVEN ASUSER SEMANTICS ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file(){ f="$1"; [ -f "$f" ] || { echo missing; return; }; if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi; echo "$1"; }
find_helper(){ for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do [ -x "$p" ] && { echo "$p"; return; }; done; }
find_app_pid(){
  if command -v pidof >/dev/null 2>&1; then P="$(pidof 3105 2>/dev/null || true)"; set -- $P; [ -n "${1:-}" ] && { echo "$1"; return; }; fi
  /bin/ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done
}
cleanup(){
  pass=0
  while [ "$pass" -lt 4 ]; do
    killall -9 3105 2>/dev/null || true
    for p in $(pidof 3105 2>/dev/null || true); do kill -9 "$p" 2>/dev/null || true; done
    sleep 1
    [ -z "$(find_app_pid)" ] && return 0
    pass=$((pass+1))
  done
  return 1
}

EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE" 2>/dev/null)"
GOT="$(hash_file "$IPA")"
echo "expected=$EXPECTED"
echo "got=$GOT"
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$GOT" ] || exit 90

H="$(find_helper)"
echo "helper=$H"
[ -n "$H" ] || exit 91
cleanup || true
rm -f "$MARKER" "$PHASE" "$LOG"
"$H" install force "$IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
[ "$IRC" -eq 0 ] || exit 93
"$H" refresh 2>&1 || true
sleep 5

LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
APP="${LINE#* : }"
echo "registration=$LINE"
echo "app=$APP"
[ -x "$APP/3105" ] || exit 94

if cleanup; then echo CLEAN_BASELINE=1; else echo CLEAN_BASELINE=0; exit 95; fi
rm -f "$MARKER" "$PHASE" "$LOG"

echo '===== EXACT PROVEN METHOD: LAUNCHCTL ASUSER 501 ====='
launchctl asuser 501 "$UIOPEN" --bundleid "$BUNDLE" > "$LOG" 2>&1
ASRC=$?
echo "asuser_rc=$ASRC"
cat "$LOG" 2>/dev/null | head -n 120 || true

READY=0
PID=''
n=0
while [ "$n" -lt 40 ]; do
  PID="$(find_app_pid)"
  if [ -s "$MARKER" ]; then READY=1; echo "ui_marker_at_second=$n"; break; fi
  if [ -s "$PHASE" ]; then echo "phase_second_${n}=$(tail -n 1 "$PHASE" 2>/dev/null)"; fi
  [ -n "$PID" ] && echo "pid_second_${n}=$PID"
  n=$((n+1))
  sleep 1
done

echo '--- phase trace ---'
[ -s "$PHASE" ] && cat "$PHASE" || echo PHASE_EMPTY=1
echo '--- UI marker ---'
[ -s "$MARKER" ] && cat "$MARKER" || echo UI_EMPTY=1
PID="$(find_app_pid)"
echo "launch_pid=$PID"

if [ "$READY" -ne 1 ]; then
  echo EARLY_WINDOW_UI_SUCCESS=0
  exit 96
fi

grep -q '^UI_READY=1$' "$MARKER" || exit 97
grep -q '^hidden=0$' "$MARKER" || exit 98
grep -q '^root_view_loaded=1$' "$MARKER" || exit 99
[ -n "$PID" ] || exit 100

STABLE=1
i=1
while [ "$i" -le 12 ]; do
  sleep 5
  P2="$(find_app_pid)"
  echo "hold_${i}_pid=$P2"
  if [ -z "$P2" ] || [ "$P2" != "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then STABLE=0; break; fi
  i=$((i+1))
done

echo "stable_pid=$PID"
echo "alive_after_60_seconds=$STABLE"
[ "$STABLE" -eq 1 ] || exit 101

echo launch_method=ASUSER_SYNC
echo EARLY_WINDOW_UI_SUCCESS=1
echo RUNTIME_PROOF_SUCCESS=1
exit 0
