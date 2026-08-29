#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
IPA='/var/mobile/Media/3105-ios15-hybrid.ipa'
EXPECT_SHA_FILE='/var/mobile/Media/3105-ios15-hybrid.sha256'
UICACHE=/var/jb/usr/bin/uicache
UIOPEN=/var/jb/usr/bin/uiopen

echo '=== 3105 IOS15 HYBRID ENTITLEMENT PROOF ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file() {
  f="$1"
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

wait_pid() {
  n=0
  while [ "$n" -lt 20 ]; do
    P="$(find_pid)"
    [ -n "$P" ] && { echo "$P"; return 0; }
    n=$((n+1)); sleep 1
  done
  return 1
}

[ -f "$IPA" ] || { echo HYBRID_IPA_MISSING=1; exit 70; }
GOT="$(hash_file "$IPA")"
EXPECT="$(cat "$EXPECT_SHA_FILE" 2>/dev/null | tr -d ' \r\n')"
echo "hybrid_device_sha=$GOT"
echo "hybrid_expected_sha=$EXPECT"
[ -n "$EXPECT" ] && [ "$GOT" = "$EXPECT" ] || { echo HYBRID_HASH_MISMATCH=1; exit 71; }
echo HYBRID_HASH_MATCH=1

H="$(find_helper)"
echo "trollstorehelper=$H"
[ -n "$H" ] || { echo TROLLSTORE_HELPER_MISSING=1; exit 72; }

killall 3105 2>/dev/null || true
sleep 2
"$H" install force "$IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
if [ "$IRC" -ne 0 ]; then
  "$H" install force installd "$IPA" 2>&1
  IRC=$?
  echo "install_installd_rc=$IRC"
fi
[ "$IRC" -eq 0 ] || exit 73
"$H" refresh 2>&1 || true
sleep 5

printf '\n===== LAUNCHSERVICES TYPE / PATH =====\n'
"$UICACHE" -i "$BUNDLE" 2>&1 || true
LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo "registration=$LINE"
APP="${LINE#* : }"
echo "registered_path=$APP"
[ -d "$APP" ] || { echo REGISTERED_APP_MISSING=1; exit 74; }

printf '\n===== HYBRID ENTITLEMENTS =====\n'
if [ -x /var/jb/usr/bin/ldid ]; then
  /var/jb/usr/bin/ldid -e "$APP/3105" 2>&1 | tee /var/mobile/Media/3105-hybrid-entitlements.txt
  if grep -q '<key>platform-application</key>' /var/mobile/Media/3105-hybrid-entitlements.txt; then
    echo PLATFORM_APPLICATION_STILL_PRESENT=1
    exit 75
  else
    echo PLATFORM_APPLICATION_ABSENT=1
  fi
  grep -q '<key>com.apple.private.MobileContainerManager.allowed</key>' /var/mobile/Media/3105-hybrid-entitlements.txt && echo MCM_ENTITLEMENT_PRESENT=1
  grep -q '<key>com.apple.private.security.no-sandbox</key>' /var/mobile/Media/3105-hybrid-entitlements.txt && echo NO_SANDBOX_ENTITLEMENT_PRESENT=1
fi

killall 3105 2>/dev/null || true
sleep 3

printf '\n===== SPRINGBOARD LAUNCH AS MOBILE =====\n'
sudo -u mobile "$UIOPEN" --bundleid "$BUNDLE" 2>&1
echo "uiopen_rc=$?"
PID="$(wait_pid)"
if [ -z "$PID" ]; then
  echo BUNDLE_LAUNCH_NO_PID=1
  sudo -u mobile "$UIOPEN" --path "$APP" 2>&1
  echo "uiopen_path_rc=$?"
  PID="$(wait_pid)"
fi

if [ -z "$PID" ]; then
  echo NO_PROCESS_AFTER_HYBRID_LAUNCH=1
  printf '\n===== DIRECT CONTROL =====\n'
  sudo -u mobile "$APP/3105" >/var/mobile/Media/3105-hybrid-direct.log 2>&1 &
  WP=$!
  sleep 12
  if kill -0 "$WP" 2>/dev/null; then echo HYBRID_DIRECT_ALIVE_AFTER_12S=1; else echo HYBRID_DIRECT_ALIVE_AFTER_12S=0; fi
  ps ax 2>/dev/null | while read pid rest; do case "$pid $rest" in *3105*) echo "PS_MATCH $pid $rest";; esac; done
  cat /var/mobile/Media/3105-hybrid-direct.log 2>/dev/null | head -n 160 || true
  exit 76
fi

echo "launch_pid=$PID"
n=0
while [ "$n" -lt 18 ]; do
  kill -0 "$PID" 2>/dev/null || { echo "PROCESS_DIED_CHECK=$n"; exit 77; }
  n=$((n+1))
  echo "ALIVE_$n pid=$PID"
  sleep 5
done
PID2="$(find_pid)"
echo "final_pid=$PID2"
[ "$PID2" = "$PID" ] || { echo "PID_CHANGED old=$PID new=$PID2"; exit 78; }
echo alive_after_90_seconds=1
echo "stable_pid=$PID"
echo RUNTIME_PROOF_SUCCESS=1
rm -f "$IPA" "$EXPECT_SHA_FILE"
exit 0
