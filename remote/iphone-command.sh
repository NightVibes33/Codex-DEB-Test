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

echo '=== 3105 IOS15 EARLY WINDOW ASUSER PROOF ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file(){ f="$1"; if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi; echo "$1"; }
find_helper(){ for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do [ -x "$p" ] && { echo "$p"; return; }; done; }
find_sb(){ /bin/ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/System/Library/CoreServices/SpringBoard.app/SpringBoard'*) echo "$pid"; break;; esac; done; }
find_app_pid(){ /bin/ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done; }
cleanup(){ killall -9 3105 2>/dev/null || true; killall -9 uiopen 2>/dev/null || true; sleep 2; }

EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE" 2>/dev/null)"
GOT="$(hash_file "$IPA")"
echo "expected=$EXPECTED"
echo "got=$GOT"
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$GOT" ] || exit 90

H="$(find_helper)"
SBPID="$(find_sb)"
echo "helper=$H"
echo "springboard_pid=$SBPID"
[ -n "$H" ] || exit 91
[ -n "$SBPID" ] || exit 92

cleanup
rm -f "$MARKER" "$PHASE" "$LOG"
"$H" install force "$IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
[ "$IRC" -eq 0 ] || exit 93
"$H" refresh 2>&1 || true
sleep 5

LINE="$("$UICACHE" -l 2>&1 | grep "$BUNDLE" | head -n 1)"
APP="${LINE#* : }"
echo "registration=$LINE"
echo "app=$APP"
[ -x "$APP/3105" ] || exit 94

cleanup
rm -f "$MARKER" "$PHASE"
echo '--- launching in UID 501 GUI bootstrap ---'
launchctl asuser 501 "$UIOPEN" --bundleid "$BUNDLE" > "$LOG" 2>&1 &
LP=$!
echo "uiopen_launcher=$LP"

READY=0
n=0
while [ "$n" -lt 25 ]; do
  if [ -s "$MARKER" ]; then READY=1; echo "ui_marker_at_second=$n"; break; fi
  if [ -s "$PHASE" ]; then echo "phase_second_${n}=$(tail -n 1 "$PHASE" 2>/dev/null)"; fi
  n=$((n+1))
  sleep 1
done
kill "$LP" 2>/dev/null || true
killall -9 uiopen 2>/dev/null || true

echo '--- phase trace ---'
[ -s "$PHASE" ] && cat "$PHASE" || echo PHASE_EMPTY=1
echo '--- UI marker ---'
[ -s "$MARKER" ] && cat "$MARKER" || echo UI_EMPTY=1
echo '--- uiopen log ---'
cat "$LOG" 2>/dev/null | head -n 120 || true

if [ "$READY" -ne 1 ]; then
  echo EARLY_WINDOW_UI_SUCCESS=0
  exit 95
fi

grep -q '^UI_READY=1$' "$MARKER" || exit 96
grep -q '^hidden=0$' "$MARKER" || exit 97
grep -q '^root_view_loaded=1$' "$MARKER" || exit 98

PID="$(find_app_pid)"
echo "initial_app_pid=$PID"
[ -n "$PID" ] || exit 99

STABLE=1
i=1
while [ "$i" -le 12 ]; do
  sleep 5
  P2="$(find_app_pid)"
  echo "hold_${i}_pid=$P2"
  if [ -z "$P2" ] || [ "$P2" != "$PID" ]; then STABLE=0; break; fi
  i=$((i+1))
done

echo "stable_pid=$PID"
echo "alive_after_60_seconds=$STABLE"
[ "$STABLE" -eq 1 ] || exit 100

echo "launch_method=ASUSER"
echo EARLY_WINDOW_UI_SUCCESS=1
echo RUNTIME_PROOF_SUCCESS=1
exit 0
