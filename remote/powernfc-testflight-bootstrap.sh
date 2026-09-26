#!/bin/sh
set +e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/bin:/var/jb/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
export HOME=/var/mobile

LOG=/var/mobile/Media/PowerNFC-testflight-bootstrap.txt
exec >"$LOG" 2>&1

echo '=== TESTFLIGHT LOWER-INSTALL BOOTSTRAP ==='
date '+time=%Y-%m-%d %H:%M:%S %z'
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'build='; sw_vers -buildVersion 2>/dev/null || true
printf 'machine='; uname -m 2>/dev/null || true
echo

echo '=== STAGED FILES ==='
ls -lah /var/mobile/Media/tflowerinstall.deb /var/mobile/Media/appstorectl 2>&1 || true

echo
echo '=== INSTALL TWEAK ==='
if [ -s /var/mobile/Media/tflowerinstall.deb ]; then
  dpkg -i --force-depends /var/mobile/Media/tflowerinstall.deb 2>&1 || true
else
  echo 'tflowerinstall_deb_missing=1'
fi

echo
echo '=== INSTALL APPSTORECTL BINARY ==='
if [ -s /var/mobile/Media/appstorectl ]; then
  mkdir -p /var/jb/usr/bin
  cp -f /var/mobile/Media/appstorectl /var/jb/usr/bin/appstorectl
  chown root:wheel /var/jb/usr/bin/appstorectl 2>/dev/null || true
  chmod 755 /var/jb/usr/bin/appstorectl
fi
command -v appstorectl || true
appstorectl version 2>&1 || true

echo
echo '=== ENABLE TESTFLIGHT LOWER-INSTALL ==='
PREF=/var/jb/var/mobile/Library/Preferences/com.34306.tflowerinstall.plist
mkdir -p "$(dirname "$PREF")"
cat > "$PREF" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>enabled</key>
  <true/>
  <key>forceInstall</key>
  <true/>
  <key>iOSVersion</key>
  <string>27.0</string>
</dict>
</plist>
PLIST
chown mobile:mobile "$PREF" 2>/dev/null || true
chmod 600 "$PREF" 2>/dev/null || true
plutil -p "$PREF" 2>/dev/null || cat "$PREF"

echo
echo '=== TWEAK FILES ==='
find /var/jb/Library/MobileSubstrate/DynamicLibraries /var/jb/usr/lib/TweakInject -maxdepth 1 -type f \( -iname '*tflowerinstall*' -o -iname '*lowerinstall*' \) -print 2>/dev/null || true

echo
echo '=== RELOAD INJECTION TARGETS ==='
killall -9 TestFlight 2>/dev/null || true
killall -9 installd 2>/dev/null || true
sleep 3
ps ax 2>/dev/null | grep '[i]nstalld' || true

echo
echo '=== APP STORE ACCOUNT ==='
appstorectl accounts 2>&1 || true

echo
echo '=== TESTFLIGHT CATALOG LOOKUP ==='
LOOK=/var/mobile/Media/TestFlight-lookup.txt
appstorectl _lookup-raw com.apple.TestFlight >"$LOOK" 2>&1 || true
cat "$LOOK"
EVID="$(grep -Eio 'externalVersionId[^0-9]*[0-9]+' "$LOOK" | grep -Eo '[0-9]+' | head -n1)"
[ -n "$EVID" ] || EVID="$(grep -Eio 'appExtVrsId[^0-9]*[0-9]+' "$LOOK" | grep -Eo '[0-9]+' | head -n1)"
echo "current_testflight_evid=${EVID:-NOT_FOUND}"

echo
echo '=== INSTALL CURRENT TESTFLIGHT ==='
TFRC=99
if [ -n "$EVID" ]; then
  timeout 240s appstorectl install com.apple.TestFlight --evid "$EVID" --no-export --no-preflight --accept
  TFRC=$?
else
  echo 'No current EVID parsed; trying normal App Store install path.'
  timeout 240s appstorectl install com.apple.TestFlight --no-export --no-preflight --accept
  TFRC=$?
fi
echo "testflight_install_rc=$TFRC"

uicache -a 2>&1 || true
sleep 4

echo
echo '=== INSTALLED TESTFLIGHT PROBE ==='
TF=''
for p in /var/containers/Bundle/Application/*/TestFlight.app; do
  [ -d "$p" ] && { TF="$p"; break; }
done
if [ -z "$TF" ]; then
  for plist in /var/containers/Bundle/Application/*/*.app/Info.plist; do
    [ -f "$plist" ] || continue
    strings "$plist" 2>/dev/null | grep -Fqi 'com.apple.TestFlight' || continue
    TF="$(dirname "$plist")"
    break
  done
fi
echo "testflight_app=${TF:-NOT_FOUND}"
if [ -n "$TF" ]; then
  plutil -p "$TF/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|MinimumOSVersion' || true
fi

echo
echo '=== OPEN POWERNFC INVITE ==='
if [ -n "$TF" ] && command -v uiopen >/dev/null 2>&1; then
  uiopen 'https://testflight.apple.com/join/cjHQ9k71' 2>&1 || true
  sleep 10
  ps ax 2>/dev/null | grep '[T]estFlight' || true
  echo 'invite_opened=YES'
else
  echo 'invite_opened=NO'
fi

echo
echo '=== RECENT TESTFLIGHT CRASHES ==='
find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f -name 'TestFlight-*.ips' -print 2>/dev/null | tail -n 5 || true

echo
echo 'bootstrap_complete=1'
exit 0
