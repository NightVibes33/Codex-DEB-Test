#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
MEDIA='/var/mobile/Media'
MARKER="$MEDIA/3105-ui-ready.txt"
PHASE="$MEDIA/3105-launch-phase.txt"
RESULTS="$MEDIA/3105-entitlement-matrix-results.txt"
MANIFEST="$MEDIA/3105-matrix-sha256.txt"
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen
VARIANTS='minimal platform nosandbox platform-nosandbox'

echo '=== 3105 IOS15 ENTITLEMENT MATRIX ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true
"$UIOPEN" 2>&1 | head -n 16 || true

hash_file(){
  f="$1"
  [ -f "$f" ] || { echo missing; return; }
  if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi
  echo "$1"
}
find_helper(){
  for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
}
find_sb(){
  /bin/ps ax 2>/dev/null | while read pid rest; do
    case "$rest" in *'/System/Library/CoreServices/SpringBoard.app/SpringBoard'*) echo "$pid"; break;; esac
  done
}
find_app_pid(){
  P="$(pidof 3105 2>/dev/null || true)"; set -- $P
  [ -n "${1:-}" ] && { echo "$1"; return; }
  /bin/ps ax 2>/dev/null | while read pid rest; do
    case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac
  done
}
cleanup(){
  killall -9 3105 2>/dev/null || true
  killall -9 uiopen 2>/dev/null || true
  sleep 2
}
reset_trace(){ rm -f "$MARKER" "$PHASE"; }
last_phase(){ [ -s "$PHASE" ] && tail -n 1 "$PHASE" 2>/dev/null || true; }
wait_for_trace(){
  limit="$1"; n=0
  while [ "$n" -lt "$limit" ]; do
    [ -s "$MARKER" ] && return 0
    [ -s "$PHASE" ] && echo "trace_second_${n}=$(last_phase)"
    n=$((n+1)); sleep 1
  done
  return 1
}
classify(){
  if [ -s "$MARKER" ]; then echo UI_READY; return; fi
  if [ ! -s "$PHASE" ]; then echo PRE_MAIN_BLOCK; return; fi
  if grep -q 'phase=didFinish-enter' "$PHASE" 2>/dev/null; then echo DIDFINISH_PARTIAL; return; fi
  if grep -q 'phase=delegate-init-exit' "$PHASE" 2>/dev/null; then echo STALLED_BEFORE_DIDFINISH; return; fi
  if grep -q 'phase=main-enter' "$PHASE" 2>/dev/null; then echo MAIN_PARTIAL; return; fi
  echo CONSTRUCTOR_ONLY
}
show_trace(){
  label="$1"
  echo "----- $label phase trace -----"
  [ -s "$PHASE" ] && cat "$PHASE" || echo PHASE_EMPTY=1
  echo "----- $label UI marker -----"
  [ -s "$MARKER" ] && cat "$MARKER" || echo UI_EMPTY=1
  echo "${label}_pid=$(find_app_pid)"
}

H="$(find_helper)"
SBPID="$(find_sb)"
echo "trollstorehelper=$H"
echo "springboard_pid=$SBPID"
[ -n "$H" ] || exit 91
[ -n "$SBPID" ] || exit 92
[ -x "$UICACHE" ] || exit 93
[ -x "$UIOPEN" ] || exit 94
[ -s "$MANIFEST" ] || exit 95

: > "$RESULTS"
echo "matrix_started=$(date 2>/dev/null)" >> "$RESULTS"

# Verify every transferred IPA before touching the installed app.
for V in $VARIANTS; do
  IPA="$MEDIA/3105-matrix-$V.ipa"
  NAME="3105-matrix-$V.ipa"
  EXPECTED="$(awk -v n="$NAME" '$2==n {print $1; exit}' "$MANIFEST" 2>/dev/null)"
  GOT="$(hash_file "$IPA")"
  echo "variant=$V expected=$EXPECTED got=$GOT"
  [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$GOT" ] || { echo "$V=HASH_MISMATCH" >> "$RESULTS"; exit 96; }
done

BEST=''
for V in $VARIANTS; do
  IPA="$MEDIA/3105-matrix-$V.ipa"
  echo
  echo "================ VARIANT: $V ================"
  cleanup
  reset_trace

  "$H" install force "$IPA" 2>&1
  IRC=$?
  echo "${V}_install_rc=$IRC"
  if [ "$IRC" -ne 0 ]; then
    echo "$V=INSTALL_FAILED:$IRC" >> "$RESULTS"
    continue
  fi
  "$H" refresh 2>&1 || true
  sleep 4

  LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
  APP="${LINE#* : }"
  echo "${V}_registration=$LINE"
  echo "${V}_app=$APP"
  if [ ! -x "$APP/3105" ]; then
    echo "$V=REGISTRATION_FAILED" >> "$RESULTS"
    continue
  fi

  # Primary test: ask SpringBoard/FrontBoard to launch the registered app.
  reset_trace
  launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" > "$MEDIA/3105-$V-uiopen.log" 2>&1 &
  LP=$!
  echo "${V}_uiopen_launcher=$LP"
  wait_for_trace 14 || true
  kill "$LP" 2>/dev/null || true
  killall -9 uiopen 2>/dev/null || true
  PRIMARY="$(classify)"
  echo "${V}_primary=$PRIMARY"
  show_trace "${V}_primary"
  cat "$MEDIA/3105-$V-uiopen.log" 2>/dev/null | head -n 100 || true

  FINAL="$PRIMARY"
  # If FrontBoard produced no executable trace, directly execute once only to
  # distinguish launch-policy failure from a pre-main entitlement/dyld block.
  if [ "$PRIMARY" = PRE_MAIN_BLOCK ]; then
    cleanup
    reset_trace
    sudo -u mobile "$APP/3105" > "$MEDIA/3105-$V-direct.log" 2>&1 &
    DP=$!
    echo "${V}_direct_launcher=$DP"
    wait_for_trace 7 || true
    DIRECT="$(classify)"
    echo "${V}_direct=$DIRECT"
    show_trace "${V}_direct"
    cat "$MEDIA/3105-$V-direct.log" 2>/dev/null | head -n 120 || true
    kill "$DP" 2>/dev/null || true
    cleanup
    FINAL="${PRIMARY}/direct:${DIRECT}"
  fi

  echo "$V=$FINAL" >> "$RESULTS"
  if [ "$PRIMARY" = UI_READY ] && [ -z "$BEST" ]; then BEST="$V"; fi
  cleanup
done

echo "best_variant=$BEST" >> "$RESULTS"
echo "matrix_finished=$(date 2>/dev/null)" >> "$RESULTS"
echo
cat "$RESULTS"

# Leave the best proven variant installed and ask SpringBoard to show it.
if [ -n "$BEST" ]; then
  echo "REINSTALLING_BEST=$BEST"
  "$H" install force "$MEDIA/3105-matrix-$BEST.ipa" 2>&1
  "$H" refresh 2>&1 || true
  sleep 3
  reset_trace
  launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" > "$MEDIA/3105-best-launch.log" 2>&1 &
  wait_for_trace 12 || true
  if [ -s "$MARKER" ]; then
    echo ENTITLEMENT_MATRIX_UI_SUCCESS=1
    cat "$MARKER"
    exit 0
  fi
fi

echo ENTITLEMENT_MATRIX_UI_SUCCESS=0
exit 97
