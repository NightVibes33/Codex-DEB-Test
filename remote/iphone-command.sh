#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-windowfix.ipa'
SHA_FILE='/var/mobile/Media/3105-ios15-windowfix.sha256'
MARKER='/var/mobile/Media/3105-ui-ready.txt'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 REAL SPRINGBOARD + TWEAK ISOLATION ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true
hash_file(){ f="$1"; [ -f "$f" ]||{ echo missing; return; }; if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f"); else set -- $(shasum -a 256 "$f"); fi; echo "$1"; }
find_helper(){ for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do [ -x "$p" ]&&{ echo "$p"; return; }; done; }
find_pid(){ P="$(pidof 3105 2>/dev/null||true)"; set -- $P; [ -n "${1:-}" ]&&{ echo "$1"; return; }; ps ax 2>/dev/null|while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done; }
find_sb(){ P="$(pidof SpringBoard 2>/dev/null||true)"; set -- $P; [ -n "${1:-}" ]&&{ echo "$1"; return; }; ps ax 2>/dev/null|while read pid rest; do case "$rest" in *SpringBoard*) echo "$pid"; break;; esac; done; }
cleanup(){ killall -9 3105 2>/dev/null||true; for p in $(pidof 3105 2>/dev/null||true); do kill -9 "$p" 2>/dev/null||true; done; sleep 2; }
wait_marker(){ label="$1"; limit="$2"; n=0; while [ "$n" -lt "$limit" ]; do if [ -s "$MARKER" ]; then echo "${label}_MARKER_AT=$n"; cat "$MARKER"; return 0; fi; P="$(find_pid)"; [ -n "$P" ]&&echo "${label}_PID_${n}=$P"; n=$((n+1)); sleep 1; done; echo "${label}_NO_MARKER=1"; return 1; }

EXPECTED="$(tr -d ' \r\n' < "$SHA_FILE" 2>/dev/null)"; GOT="$(hash_file "$IPA")"; echo "expected=$EXPECTED"; echo "got=$GOT"; [ -n "$EXPECTED" ]&&[ "$EXPECTED" = "$GOT" ]||exit 90
H="$(find_helper)"; echo "helper=$H"; [ -n "$H" ]||exit 91
cleanup; rm -f "$MARKER"
"$H" install force "$IPA" 2>&1; IRC=$?; echo "install_rc=$IRC"; [ "$IRC" -eq 0 ]||exit 92
"$H" refresh 2>&1||true; sleep 5
LINE="$("$UICACHE" -l 2>&1|grep -F "$BUNDLE"|head -n 1)"; APP="${LINE#* : }"; echo "registration=$LINE"; echo "app=$APP"; [ -x "$APP/3105" ]||exit 93
SBPID="$(find_sb)"; echo "springboard_pid=$SBPID"; ps ax 2>/dev/null|grep -i SpringBoard|head -n 10||true

printf '\n===== A: REAL SPRINGBOARD BSEXEC + UIOPEN =====\n'
cleanup; rm -f "$MARKER" /var/mobile/Media/3105-A.log
if [ -n "$SBPID" ]; then launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" >/var/mobile/Media/3105-A.log 2>&1; echo "A_rc=$?"; wait_marker A 30||true; fi
cat /var/mobile/Media/3105-A.log 2>/dev/null|head -n 100||true
cleanup

printf '\n===== B: NORMAL DIRECT MOBILE =====\n'
rm -f "$MARKER" /var/mobile/Media/3105-B.log
sudo -u mobile "$APP/3105" >/var/mobile/Media/3105-B.log 2>&1 & echo "B_wrapper=$!"; wait_marker B 30||true; echo "B_final_pid=$(find_pid)"; cat /var/mobile/Media/3105-B.log 2>/dev/null|head -n 140||true
cleanup

printf '\n===== C: SAFE-MODE DIRECT MOBILE =====\n'
rm -f "$MARKER" /var/mobile/Media/3105-C.log
sudo -u mobile env _MSSafeMode=1 LIBHOOKER_SAFE_MODE=1 ELLEKIT_SAFE_MODE=1 _SafeMode=1 "$APP/3105" >/var/mobile/Media/3105-C.log 2>&1 & echo "C_wrapper=$!"; wait_marker C 30||true; echo "C_final_pid=$(find_pid)"; cat /var/mobile/Media/3105-C.log 2>/dev/null|head -n 180||true
if [ -s "$MARKER" ]; then echo SAFE_DIRECT_REACHED_UI=1; fi
cleanup

printf '\n===== D: SAFE-MODE SPRINGBOARD BSEXEC DIRECT =====\n'
rm -f "$MARKER" /var/mobile/Media/3105-D.log
if [ -n "$SBPID" ]; then launchctl bsexec "$SBPID" env _MSSafeMode=1 LIBHOOKER_SAFE_MODE=1 ELLEKIT_SAFE_MODE=1 _SafeMode=1 "$APP/3105" >/var/mobile/Media/3105-D.log 2>&1 & echo "D_wrapper=$!"; wait_marker D 30||true; fi
echo "D_final_pid=$(find_pid)"; cat /var/mobile/Media/3105-D.log 2>/dev/null|head -n 180||true
if [ -s "$MARKER" ]; then echo SAFE_BSEXEC_REACHED_UI=1; fi

printf '\n===== FINAL =====\n'
if [ -s "$MARKER" ]; then cat "$MARKER"; echo UI_MARKER_OBSERVED=1; else echo UI_MARKER_OBSERVED=0; fi
echo ISOLATION_COMPLETE=1
exit 0
