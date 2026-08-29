#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-windowfix.ipa'
SHA_FILE='/var/mobile/Media/3105-ios15-windowfix.sha256'
MARKER='/var/mobile/Media/3105-ui-ready.txt'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 UI LAUNCH POSTMORTEM ==='
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
    P="$(pidof 3105 2>/dev/null || true)"; set -- $P
    [ -n "${1:-}" ] && { echo "$1"; return; }
  fi
  ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done
}

cleanup_3105() {
  pass=0
  while [ "$pass" -lt 5 ]; do
    killall -9 3105 2>/dev/null || true
    for p in $(pidof 3105 2>/dev/null || true); do kill -9 "$p" 2>/dev/null || true; done
    ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) kill -9 "$pid" 2>/dev/null || true;; esac; done
    sleep 1
    [ -z "$(find_pid)" ] && return 0
    pass=$((pass+1))
  done
  return 1
}

wait_marker_short() {
  n=0
  while [ "$n" -lt 15 ]; do
    [ -s "$MARKER" ] && { cat "$MARKER"; return 0; }
    n=$((n+1)); sleep 1
  done
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

H="$(find_helper)"; echo "trollstorehelper=$H"; [ -n "$H" ] || exit 91
cleanup_3105 || true
rm -f "$MARKER" /var/mobile/Media/3105-*.log
"$H" install force "$IPA" 2>&1
IRC=$?; echo "install_rc=$IRC"; [ "$IRC" -eq 0 ] || exit 92
"$H" refresh 2>&1 || true
sleep 5

LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
APP="${LINE#* : }"
echo "registration=$LINE"
echo "registered_path=$APP"
[ -d "$APP" ] || exit 93
ls -la "$APP/3105" "$APP/Info.plist" 2>&1 || true
if command -v file >/dev/null 2>&1; then file "$APP/3105" 2>&1 || true; fi
if [ -x /var/jb/usr/bin/ldid ]; then
  /var/jb/usr/bin/ldid -e "$APP/3105" 2>&1 | tee /var/mobile/Media/3105-postmortem-entitlements.txt
fi

SBPID="$(pidof SpringBoard 2>/dev/null | awk '{print $1}')"
echo "springboard_pid=$SBPID"
for c in log oslog syslog jtool2 otool; do command -v "$c" 2>/dev/null && echo "tool_${c}=$(command -v "$c")"; done

printf '\n===== LS / ASUSER UIOPEN =====\n'
cleanup_3105 || true
rm -f "$MARKER"
launchctl asuser 501 "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-uiopen.log 2>&1
RC=$?; echo "uiopen_asuser_rc=$RC"; cat /var/mobile/Media/3105-uiopen.log 2>/dev/null || true
n=0
while [ "$n" -lt 15 ]; do
  P="$(find_pid)"; [ -n "$P" ] && echo "ASUSER_TRANSIENT_PID_$n=$P"
  [ -s "$MARKER" ] && break
  n=$((n+1)); sleep 1
done
[ -s "$MARKER" ] && { echo ASUSER_UI_MARKER=1; cat "$MARKER"; }
echo "asuser_final_pid=$(find_pid)"

printf '\n===== DIRECT MOBILE EXECUTION =====\n'
cleanup_3105 || true
rm -f "$MARKER" /var/mobile/Media/3105-direct-mobile.log
sudo -u mobile "$APP/3105" > /var/mobile/Media/3105-direct-mobile.log 2>&1 &
W=$!
echo "mobile_wrapper_pid=$W"
sleep 5
P="$(find_pid)"; echo "mobile_direct_pid=$P"
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then echo MOBILE_DIRECT_ALIVE_5S=1; else echo MOBILE_DIRECT_ALIVE_5S=0; fi
cat /var/mobile/Media/3105-direct-mobile.log 2>/dev/null | head -n 220 || true
[ -s "$MARKER" ] && { echo MOBILE_DIRECT_UI_MARKER=1; cat "$MARKER"; }
cleanup_3105 || true

printf '\n===== DIRECT GUI BOOTSTRAP EXECUTION =====\n'
rm -f "$MARKER" /var/mobile/Media/3105-direct-asuser.log
launchctl asuser 501 "$APP/3105" > /var/mobile/Media/3105-direct-asuser.log 2>&1 &
AW=$!
echo "direct_asuser_wrapper_pid=$AW"
sleep 8
P="$(find_pid)"; echo "direct_asuser_pid=$P"
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then echo DIRECT_ASUSER_ALIVE_8S=1; else echo DIRECT_ASUSER_ALIVE_8S=0; fi
cat /var/mobile/Media/3105-direct-asuser.log 2>/dev/null | head -n 220 || true
[ -s "$MARKER" ] && { echo DIRECT_ASUSER_UI_MARKER=1; cat "$MARKER"; }
cleanup_3105 || true

printf '\n===== SPRINGBOARD BSEXEC UIOPEN =====\n'
rm -f "$MARKER" /var/mobile/Media/3105-bsexec.log
if [ -n "$SBPID" ]; then
  launchctl bsexec "$SBPID" "$UIOPEN" --bundleid "$BUNDLE" > /var/mobile/Media/3105-bsexec.log 2>&1
  BRC=$?; echo "bsexec_uiopen_rc=$BRC"
  cat /var/mobile/Media/3105-bsexec.log 2>/dev/null || true
  sleep 12
  P="$(find_pid)"; echo "bsexec_pid=$P"
  [ -s "$MARKER" ] && { echo BSEXEC_UI_MARKER=1; cat "$MARKER"; }
fi

print_recent_crashes

printf '\n===== KERNEL / SYSTEM TAIL =====\n'
dmesg 2>/dev/null | tail -n 120 || true

if [ -s "$MARKER" ]; then
  echo UI_MARKER_OBSERVED=1
  cat "$MARKER"
else
  echo UI_MARKER_OBSERVED=0
fi
echo POSTMORTEM_COMPLETE=1
exit 0
