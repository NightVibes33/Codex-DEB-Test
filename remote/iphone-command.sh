#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-windowfix.ipa'
SHA_FILE='/var/mobile/Media/3105-ios15-windowfix.sha256'
MARKER='/var/mobile/Media/3105-ui-ready.txt'
PHASE='/var/mobile/Media/3105-launch-phase.txt'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 BOUNDED SPRINGBOARD BOOTSTRAP ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file(){ f="$1"; [ -f "$f" ] || { echo missing; return; }; if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi; echo "$1"; }
find_helper(){ for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do [ -x "$p" ] && { echo "$p"; return; }; done; }
find_pid(){ P="$(pidof 3105 2>/dev/null || true)"; set -- $P; [ -n "${1:-}" ] && { echo "$1"; return; }; /bin/ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done; }
find_sb(){ /bin/ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/System/Library/CoreServices/SpringBoard.app/SpringBoard'*) echo "$pid"; break;; esac; done; }
cleanup(){ killall -9 3105 2>/dev/null || true; killall -9 uiopen 2>/dev/null || true; sleep 2; }
reset_trace(){ rm -f "$MARKER" "$PHASE"; }
show_trace(){ label="$1"; echo "----- ${label} PHASE -----"; [ -s "$PHASE" ] && cat "$PHASE" || echo PHASE_EMPTY=1; echo "----- ${label} UI -----"; [ -s "$MARKER" ] && cat "$MARKER" || echo UI_EMPTY=1; echo "${label}_pid=$(find_pid)"; }
wait_trace(){ label="$1"; n=0; while [ "$n" -lt 18 ]; do [ -s "$MARKER" ] && { echo "${label}_UI_AT=$n"; show_trace "$label"; return 0; }; [ -s "$PHASE" ] && echo "${label}_${n}:$(tail -n 1 "$PHASE" 2>/dev/null)"; n=$((n+1)); sleep 1; done; show_trace "$label"; return 1; }
finish_launcher(){ p="$1"; [ -n "$p" ] && kill "$p" 2>/dev/null || true; killall -9 uiopen 2>/dev/null || true; }

EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE" 2>/dev/null)"; GOT="$(hash_file "$IPA")"; echo "expected=$EXPECTED"; echo "got=$GOT"; [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$GOT" ] || exit 90
H="$(find_helper)"; echo "helper=$H"; [ -n "$H" ] || exit 91
cleanup; reset_trace
"$H" install force "$IPA" 2>&1; IRC=$?; echo "install_rc=$IRC"; [ "$IRC" -eq 0 ] || exit 92
"$H" refresh 2>&1 || true; sleep 5
LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"; APP="${LINE#* : }"; echo "registration=$LINE"; echo "app=$APP"; [ -x "$APP/3105" ] || exit 93
SBPID="$(find_sb)"; echo "springboard_pid=$SBPID"; [ -n "$SBPID" ] || exit 94
launchctl print system/com.apple.SpringBoard 2>&1 | grep -E 'state =|pid =|username =' | head -n 20 || true

printf '\n===== TEST A: BSEXEC SPRINGBOARD + BUNDLE ID =====\n'
cleanup; reset_trace
launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-A.log 2>&1 &
LA=$!; echo "A_launcher=$LA"; sleep 1
if wait_trace A; then
  finish_launcher "$LA"; P="$(find_pid)"; sleep 10; P2="$(find_pid)"; echo "A_pid_before=$P"; echo "A_pid_after=$P2"; [ -n "$P2" ] && [ "$P" = "$P2" ] && echo A_STABLE=1 || echo A_STABLE=0
  echo REAL_SPRINGBOARD_UI_SUCCESS=1; exit 0
fi
finish_launcher "$LA"; cat /var/mobile/Media/3105-A.log 2>/dev/null | head -n 120 || true

printf '\n===== TEST B: BSEXEC SPRINGBOARD + URL =====\n'
cleanup; reset_trace
launchctl bsexec "$SBPID" "$UIOPEN" --url 'threeoneosfive://' > /var/mobile/Media/3105-B.log 2>&1 &
LB=$!; echo "B_launcher=$LB"; sleep 1
if wait_trace B; then
  finish_launcher "$LB"; P="$(find_pid)"; sleep 10; P2="$(find_pid)"; echo "B_pid_before=$P"; echo "B_pid_after=$P2"; [ -n "$P2" ] && [ "$P" = "$P2" ] && echo B_STABLE=1 || echo B_STABLE=0
  echo REAL_SPRINGBOARD_UI_SUCCESS=1; exit 0
fi
finish_launcher "$LB"; cat /var/mobile/Media/3105-B.log 2>/dev/null | head -n 120 || true

printf '\n===== TEST C: BSEXEC SPRINGBOARD + MOBILE UIOPEN =====\n'
cleanup; reset_trace
launchctl bsexec "$SBPID" sudo -u mobile "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-C.log 2>&1 &
LC=$!; echo "C_launcher=$LC"; sleep 1
if wait_trace C; then
  finish_launcher "$LC"; P="$(find_pid)"; sleep 10; P2="$(find_pid)"; echo "C_pid_before=$P"; echo "C_pid_after=$P2"; [ -n "$P2" ] && [ "$P" = "$P2" ] && echo C_STABLE=1 || echo C_STABLE=0
  echo REAL_SPRINGBOARD_UI_SUCCESS=1; exit 0
fi
finish_launcher "$LC"; cat /var/mobile/Media/3105-C.log 2>/dev/null | head -n 120 || true

printf '\n===== TEST D: DIRECT TRACE CONTROL =====\n'
cleanup; reset_trace
sudo -u mobile "$APP/3105" > /var/mobile/Media/3105-D.log 2>&1 &
LD=$!; echo "D_wrapper=$LD"; wait_trace D || true; kill "$LD" 2>/dev/null || true
cat /var/mobile/Media/3105-D.log 2>/dev/null | head -n 180 || true

echo REAL_SPRINGBOARD_UI_SUCCESS=0
exit 0
