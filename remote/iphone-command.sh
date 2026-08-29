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

echo '=== 3105 IOS15 LIFECYCLE TRACE ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file() {
  f="$1"
  [ -f "$f" ] || { echo missing; return; }
  if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi
  echo "$1"
}

find_helper() {
  for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
}

find_pid() {
  P="$(pidof 3105 2>/dev/null || true)"; set -- $P
  [ -n "${1:-}" ] && { echo "$1"; return; }
  ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done
}

cleanup() {
  killall -9 3105 2>/dev/null || true
  for p in $(pidof 3105 2>/dev/null || true); do kill -9 "$p" 2>/dev/null || true; done
  sleep 2
}

reset_trace() {
  rm -f "$MARKER" "$PHASE"
}

show_trace() {
  label="$1"
  echo "----- ${label} PHASE TRACE -----"
  if [ -s "$PHASE" ]; then cat "$PHASE"; else echo PHASE_TRACE_EMPTY=1; fi
  echo "----- ${label} UI MARKER -----"
  if [ -s "$MARKER" ]; then cat "$MARKER"; else echo UI_MARKER_EMPTY=1; fi
  echo "----- ${label} PROCESS -----"
  echo "pid=$(find_pid)"
}

wait_trace() {
  label="$1"
  n=0
  while [ "$n" -lt 20 ]; do
    if [ -s "$MARKER" ]; then
      echo "${label}_UI_AT_SECOND=$n"
      show_trace "$label"
      return 0
    fi
    if [ -s "$PHASE" ]; then
      last="$(tail -n 1 "$PHASE" 2>/dev/null)"
      echo "${label}_PHASE_${n}=$last"
    fi
    n=$((n+1))
    sleep 1
  done
  show_trace "$label"
  return 1
}

EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE" 2>/dev/null)"
GOT="$(hash_file "$IPA")"
echo "expected_ipa_sha=$EXPECTED"
echo "device_ipa_sha=$GOT"
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$GOT" ] || exit 90

H="$(find_helper)"
echo "trollstorehelper=$H"
[ -n "$H" ] || exit 91
cleanup
reset_trace
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
[ -x "$APP/3105" ] || exit 93

printf '\n===== PROCESS / BOOTSTRAP DISCOVERY =====\n'
echo "pidof_springboard=$(pidof SpringBoard 2>/dev/null || true)"
echo "pgrep_springboard=$(pgrep -x SpringBoard 2>/dev/null || true)"
for PS in /bin/ps /var/jb/bin/ps /var/jb/usr/bin/ps; do
  [ -x "$PS" ] || continue
  echo "ps_tool=$PS"
  "$PS" ax 2>/dev/null | grep -i '[S]pringBoard' | head -n 8 || true
  "$PS" -A 2>/dev/null | grep -i '[S]pringBoard' | head -n 8 || true
done
for domain in gui/501 system/com.apple.SpringBoard gui/501/com.apple.SpringBoard; do
  echo "launchctl_print=$domain"
  launchctl print "$domain" 2>&1 | head -n 80 || true
done

printf '\n===== TEST A: ASUSER + MOBILE + UIOPEN BUNDLE =====\n'
cleanup; reset_trace
launchctl asuser 501 sudo -u mobile "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-A.log 2>&1
ARC=$?
echo "A_rc=$ARC"
cat /var/mobile/Media/3105-A.log 2>/dev/null | head -n 120 || true
wait_trace A || true

printf '\n===== TEST B: ASUSER + MOBILE + UIOPEN URL =====\n'
cleanup; reset_trace
launchctl asuser 501 sudo -u mobile "$UIOPEN" --url 'threeoneosfive://' > /var/mobile/Media/3105-B.log 2>&1
BRC=$?
echo "B_rc=$BRC"
cat /var/mobile/Media/3105-B.log 2>/dev/null | head -n 120 || true
wait_trace B || true

printf '\n===== TEST C: DIRECT MOBILE, NORMAL INJECTION =====\n'
cleanup; reset_trace
sudo -u mobile "$APP/3105" > /var/mobile/Media/3105-C.log 2>&1 &
CWRAP=$!
echo "C_wrapper=$CWRAP"
wait_trace C || true
cat /var/mobile/Media/3105-C.log 2>/dev/null | head -n 180 || true
cleanup

printf '\n===== TEST D: DIRECT MOBILE, TWEAK SAFE MODE =====\n'
reset_trace
sudo -u mobile env _MSSafeMode=1 LIBHOOKER_SAFE_MODE=1 ELLEKIT_SAFE_MODE=1 _SafeMode=1 "$APP/3105" > /var/mobile/Media/3105-D.log 2>&1 &
DWRAP=$!
echo "D_wrapper=$DWRAP"
wait_trace D || true
cat /var/mobile/Media/3105-D.log 2>/dev/null | head -n 180 || true
cleanup

printf '\n===== TEST E: LAUNCHCTL ASUSER DIRECT SAFE MODE =====\n'
reset_trace
launchctl asuser 501 sudo -u mobile env _MSSafeMode=1 LIBHOOKER_SAFE_MODE=1 ELLEKIT_SAFE_MODE=1 _SafeMode=1 "$APP/3105" > /var/mobile/Media/3105-E.log 2>&1 &
EWRAP=$!
echo "E_wrapper=$EWRAP"
wait_trace E || true
cat /var/mobile/Media/3105-E.log 2>/dev/null | head -n 180 || true

printf '\n===== FINAL DIAGNOSIS INPUT =====\n'
show_trace FINAL
for f in /var/mobile/Media/3105-A.log /var/mobile/Media/3105-B.log /var/mobile/Media/3105-C.log /var/mobile/Media/3105-D.log /var/mobile/Media/3105-E.log; do
  [ -s "$f" ] && { echo "LOG=$f"; tail -n 80 "$f"; }
done

echo LIFECYCLE_TRACE_COMPLETE=1
exit 0
