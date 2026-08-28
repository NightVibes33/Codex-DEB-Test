#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
RFMON=/var/jb/usr/local/bin/rfmonctl

echo '=== IOS WIFI ENTITLEMENT GATE TRACE ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== ENTITLEMENT TOOLING =====\n'
for b in ldid codesign jtool jtool2; do
  q=$(command -v "$b" 2>/dev/null)
  [ -n "$q" ] && echo "$b=$q" || echo "$b=NOT_FOUND"
done
LDID=$(command -v ldid 2>/dev/null)

printf '\n===== CANDIDATE WIFI BINARIES =====\n'
CANDIDATES="
/usr/sbin/wifid
/usr/libexec/wifianalyticsd
/usr/libexec/wifivelocityd
/usr/libexec/wifip2pd
/usr/libexec/airportd
/usr/libexec/WiFiVelocityAgent
/System/Library/PrivateFrameworks/WiFiPolicy.framework/XPCServices/WiFiPolicyXPC.xpc/WiFiPolicyXPC
/System/Library/PrivateFrameworks/WiFiKit.framework/XPCServices/WiFiKitXPC.xpc/WiFiKitXPC
"
for p in $CANDIDATES; do
  [ -e "$p" ] && ls -l "$p"
done

printf '\n===== RFMONCTL ENTITLEMENTS =====\n'
if [ -n "$LDID" ] && [ -e "$RFMON" ]; then
  "$LDID" -e "$RFMON" 2>&1 | head -n 240
else
  echo 'rfmon_entitlements=unavailable'
fi

printf '\n===== SYSTEM WIFI ENTITLEMENTS =====\n'
if [ -n "$LDID" ]; then
  for p in $CANDIDATES; do
    [ -e "$p" ] || continue
    echo "--- ENTITLEMENTS $p ---"
    "$LDID" -e "$p" 2>&1 | head -n 320
  done
else
  echo 'system_wifi_entitlements=ldid-missing'
fi

printf '\n===== WIFI-RELATED EXECUTABLE NAMES =====\n'
for root in /usr/sbin /usr/libexec; do
  [ -d "$root" ] || continue
  find "$root" -maxdepth 1 -type f -print 2>/dev/null | grep -Ei '/(wifi|airport|wireless|80211)' | head -n 120
done

printf '\n===== RUNNING WIFI PROCESSES =====\n'
ps axww 2>/dev/null | grep -Ei '[w]ifi|[a]irport|80211' | head -n 100 || true

printf '\n===== IO80211 USERCLIENT REGISTRY =====\n'
ioreg -l -w0 2>/dev/null | grep -Ei 'IO80211APIUserClient|AppleBCMWLANUserClient|IO80211InterfaceMonitor|IO80211ControllerMonitor' | head -n 120 || true

printf '\n===== CONTROL TEST (GET ONLY) =====\n'
if [ -x "$RFMON" ]; then
  "$RFMON" en0 get 2>&1
  echo "rfmon_get_rc=$?"
fi

echo '=== END IOS WIFI ENTITLEMENT GATE TRACE ==='
