#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile
LOG=/var/mobile/Media/TestFlight-explicit-evid-probe.txt
exec >"$LOG" 2>&1

echo '=== TESTFLIGHT EXPLICIT EVID PROBE ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
appstorectl version 2>&1 || true

echo
echo '=== LIBRARY RAW ==='
timeout 90s appstorectl _library-raw com.apple.TestFlight 2>&1 || true

echo
echo '=== VERSION LOOKUP ==='
timeout 90s appstorectl versions com.apple.TestFlight 2>&1 || true

find_tf() {
  for p in /var/containers/Bundle/Application/*/TestFlight.app; do
    [ -d "$p" ] && { printf '%s' "$p"; return 0; }
  done
  for plist in /var/containers/Bundle/Application/*/*.app/Info.plist; do
    [ -f "$plist" ] || continue
    strings "$plist" 2>/dev/null | grep -Fqi 'com.apple.TestFlight' || continue
    dirname "$plist"
    return 0
  done
  return 1
}

describe_tf() {
  p="$(find_tf)"
  [ -n "$p" ] || return 1
  echo "testflight_path=$p"
  plutil -p "$p/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|MinimumOSVersion' || true
  if command -v ldid >/dev/null 2>&1; then
    exe="$(plutil -extract CFBundleExecutable raw -o - "$p/Info.plist" 2>/dev/null)"
    [ -n "$exe" ] && ldid -e "$p/$exe" 2>/dev/null | head -n 80 || true
  fi
  return 0
}

echo
echo '=== CLEAN PLACEHOLDER ==='
appstorectl uninstall com.apple.TestFlight 2>&1 || true
uicache -a 2>&1 || true
sleep 2

# Known public TestFlight external version IDs, newest candidate first.
# The targeted lower-install tweak already spoofs the compatibility check to iOS 27.0.
for spec in '866586266:3.5.2' '856134955:3.3.1' '630253062:0.8.0'; do
  evid="${spec%%:*}"
  label="${spec#*:}"
  echo
  echo "=== TRY EVID $evid ($label) ==="
  timeout 180s appstorectl install com.apple.TestFlight --evid "$evid" --no-export --no-preflight --accept 2>&1
  rc=$?
  echo "install_rc=$rc"
  uicache -a 2>&1 || true
  sleep 4
  if describe_tf; then
    echo "selected_evid=$evid"
    echo "selected_version_hint=$label"
    echo 'testflight_install_status=INSTALLED'
    echo
    echo '=== LAUNCH TESTFLIGHT ==='
    uiopen 'itms-beta://' 2>&1 || true
    sleep 6
    ps ax 2>/dev/null | grep '[T]estFlight' || true
    echo
    echo '=== OPEN POWERNFC INVITE ==='
    uiopen 'https://testflight.apple.com/join/cjHQ9k71' 2>&1 || true
    sleep 8
    ps ax 2>/dev/null | grep '[T]estFlight' || true
    echo 'invite_opened=YES'
    echo 'probe_complete=1'
    exit 0
  fi
  echo "evid_failed=$evid"
  appstorectl uninstall com.apple.TestFlight 2>&1 || true
  sleep 2
done

echo 'testflight_install_status=FAILED'
echo 'probe_complete=1'
exit 0
