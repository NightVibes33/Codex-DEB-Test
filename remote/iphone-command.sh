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

echo '=== 3105 IOS15 ENTITLEMENT MATRIX POSIX PARSER ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file(){
  f="$1"
  [ -f "$f" ] || { echo missing; return; }
  if command -v sha256sum >/dev/null 2>&1; then
    set -- $(sha256sum "$f" 2>/dev/null)
  else
    set -- $(shasum -a 256 "$f" 2>/dev/null)
  fi
  echo "$1"
}

manifest_hash(){
  wanted="$1"
  while IFS=' ' read -r hash name extra; do
    [ -n "$hash" ] || continue
    [ "$name" = "$wanted" ] && { echo "$hash"; return 0; }
    [ "$extra" = "$wanted" ] && { echo "$hash"; return 0; }
  done < "$MANIFEST"
  return 1
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
cleanup(){ killall -9 3105 2>/dev/null || true; killall -9 uiopen 2>/dev/null || true; sleep 2; }
reset_trace(){ rm -f "$MARKER" "$PHASE"; }
classify(){
  [ -s "$MARKER" ] && { echo UI_READY; return; }
  [ ! -s "$PHASE" ] && { echo PRE_MAIN_BLOCK; return; }
  grep -q 'phase=didFinish-enter' "$PHASE" 2>/dev/null && { echo DIDFINISH_PARTIAL; return; }
  grep -q 'phase=delegate-init-exit' "$PHASE" 2>/dev/null && { echo STALLED_BEFORE_DIDFINISH; return; }
  grep -q 'phase=main-enter' "$PHASE" 2>/dev/null && { echo MAIN_PARTIAL; return; }
  echo CONSTRUCTOR_ONLY
}
wait_seconds(){ limit="$1"; n=0; while [ "$n" -lt "$limit" ]; do [ -s "$MARKER" ] && return 0; n=$((n+1)); sleep 1; done; return 1; }

H="$(find_helper)"
SBPID="$(find_sb)"
echo "helper=$H"
echo "springboard_pid=$SBPID"
[ -n "$H" ] || exit 91
[ -n "$SBPID" ] || exit 92
[ -s "$MANIFEST" ] || exit 93

echo '--- manifest ---'
cat "$MANIFEST"
: > "$RESULTS"
BEST=''

for V in $VARIANTS; do
  NAME="3105-matrix-$V.ipa"
  IPA="$MEDIA/$NAME"
  EXPECTED="$(manifest_hash "$NAME")"
  GOT="$(hash_file "$IPA")"
  echo "variant=$V expected=$EXPECTED got=$GOT"
  if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$GOT" ]; then
    echo "$V=HASH_MISMATCH" >> "$RESULTS"
    continue
  fi

  cleanup; reset_trace
  "$H" install force "$IPA" >/dev/null 2>&1
  IRC=$?
  echo "${V}_install_rc=$IRC"
  if [ "$IRC" -ne 0 ]; then echo "$V=INSTALL_FAILED:$IRC" >> "$RESULTS"; continue; fi
  "$H" refresh >/dev/null 2>&1 || true
  sleep 3

  LINE="$("$UICACHE" -l 2>&1 | grep "$BUNDLE" | head -n 1)"
  APP="${LINE#* : }"
  echo "${V}_registration=$LINE"
  [ -x "$APP/3105" ] || { echo "$V=REGISTRATION_FAILED" >> "$RESULTS"; continue; }

  reset_trace
  launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" > "$MEDIA/3105-$V-uiopen.log" 2>&1 &
  LP=$!
  wait_seconds 12 || true
  kill "$LP" 2>/dev/null || true
  killall -9 uiopen 2>/dev/null || true
  PRIMARY="$(classify)"
  echo "${V}_primary=$PRIMARY"
  [ -s "$PHASE" ] && cat "$PHASE" || echo "${V}_phase_empty=1"
  [ -s "$MARKER" ] && cat "$MARKER" || true

  DIRECT='SKIPPED'
  if [ "$PRIMARY" = PRE_MAIN_BLOCK ]; then
    cleanup; reset_trace
    sudo -u mobile "$APP/3105" > "$MEDIA/3105-$V-direct.log" 2>&1 &
    DP=$!
    wait_seconds 6 || true
    DIRECT="$(classify)"
    echo "${V}_direct=$DIRECT"
    [ -s "$PHASE" ] && cat "$PHASE" || echo "${V}_direct_phase_empty=1"
    kill "$DP" 2>/dev/null || true
  fi

  echo "$V=$PRIMARY/direct:$DIRECT" >> "$RESULTS"
  [ "$PRIMARY" = UI_READY ] && [ -z "$BEST" ] && BEST="$V"
  cleanup
done

echo "best_variant=$BEST" >> "$RESULTS"
cat "$RESULTS"
[ -n "$BEST" ] && echo ENTITLEMENT_MATRIX_UI_SUCCESS=1 || echo ENTITLEMENT_MATRIX_UI_SUCCESS=0
exit 0
