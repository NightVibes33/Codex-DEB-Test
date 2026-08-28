#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl
LDID=$(command -v ldid 2>/dev/null)
ENT=/tmp/rfmon-wifi-entitlements.plist

echo '=== IOS RFMON MINIMAL ENTITLEMENT TEST ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== PRECHECK =====\n'
ls -l "$RFMON" 2>&1 || true
echo "ldid=${LDID:-NOT_FOUND}"
if [ ! -x "$RFMON" ] || [ -z "$LDID" ]; then
  echo 'result=missing-rfmonctl-or-ldid'
  exit 0
fi

cat > "$ENT" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.wifi.manager-access</key>
  <true/>
  <key>com.apple.wlan.authentication</key>
  <true/>
  <key>com.apple.security.iokit-user-client-class</key>
  <array>
    <string>IO80211APIUserClient</string>
  </array>
</dict>
</plist>
PLIST

printf '\n===== APPLY MINIMAL ENTITLEMENTS =====\n'
cat "$ENT"
cp "$RFMON" /tmp/rfmonctl.pre-entitlements 2>/dev/null || true
"$LDID" -S"$ENT" "$RFMON" 2>&1
SIGN_RC=$?
echo "ldid_sign_rc=$SIGN_RC"
ls -l "$RFMON" 2>&1 || true

printf '\n===== VERIFY EMBEDDED ENTITLEMENTS =====\n'
"$LDID" -e "$RFMON" 2>&1 | head -n 180

printf '\n===== GET MONITOR STATE WITH ENTITLEMENTS =====\n'
if [ "$SIGN_RC" -eq 0 ]; then
  "$RFMON" en0 get 2>&1
  GET_RC=$?
  echo "rfmon_entitled_get_rc=$GET_RC"
else
  echo 'rfmon_entitled_get_skipped=sign-failed'
fi

printf '\n===== IO80211 CLIENT COUNT AFTER =====\n'
ioreg -l -w0 2>/dev/null | grep -E 'IO80211APIUserClient  <class' | head -n 20 || true

echo '=== END IOS RFMON MINIMAL ENTITLEMENT TEST ==='
