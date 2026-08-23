#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile
APP=/var/jb/Applications/Zebra.app
BIN="$APP/Zebra"
CR=/var/mobile/Library/Logs/CrashReporter

echo '=== Zebra tweak-injection + entitlement diagnostic ==='
printf 'started='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'ios='; sw_vers -productVersion 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true

echo '--- Dopamine / jbctl ---'
for p in /var/jb/basebin/jbctl /var/jb/basebin/jbinfo /var/jb/basebin/jailbreakd; do [ -e "$p" ] && ls -l "$p"; done
/var/jb/basebin/jbctl version 2>&1 || /var/jb/basebin/jbctl info 2>&1 || true
cat /var/jb/.installed_dopamine 2>/dev/null || true

echo '--- Zebra package ---'
dpkg-query -W -f='${Status} | ${Package} | ${Version} | ${Architecture}\n' xyz.willy.zebra 2>/dev/null || true
apt-cache policy xyz.willy.zebra 2>/dev/null || true

echo '--- Zebra entitlements ---'
if command -v ldid >/dev/null 2>&1; then
  ldid -e "$BIN" 2>&1 || true
else
  echo 'ldid=missing'
fi

echo '--- Zebra Info.plist relevant keys ---'
if command -v plutil >/dev/null 2>&1; then
  plutil -p "$APP/Info.plist" 2>/dev/null | grep -Ei 'BundleIdentifier|Executable|MinimumOS|UIApplication|LSApplication|UIRequired|CFBundleVersion|CFBundleShort' || true
else
  strings "$APP/Info.plist" 2>/dev/null | grep -Ei 'xyz.willy|Zebra|MinimumOS' | head -n 40 || true
fi

echo '--- tweak loaders / injection ---'
dpkg-query -W -f='${Package} ${Version} ${Architecture}\n' 2>/dev/null | grep -Ei 'ellekit|choicy|substitute|libhooker|substrate' || true
ls -la /var/jb/usr/lib/TweakInject 2>/dev/null | head -n 100 || true
ls -la /var/jb/Library/MobileSubstrate/DynamicLibraries 2>/dev/null | head -n 100 || true

echo '--- recent reports mentioning Zebra before safe test ---'
find "$CR" -type f -mmin -15 -print 2>/dev/null | while IFS= read -r f; do grep -Il 'Zebra\|xyz.willy.Zebra' "$f" 2>/dev/null; done | head -n 30

echo '--- safe-mode launch test ---'
killall -9 Zebra 2>/dev/null || true
# Dopamine systemhook honors DISABLE_TWEAKS=1 for child app launches when inherited.
launchctl setenv DISABLE_TWEAKS 1 2>&1 || true
launchctl setenv _MSSafeMode 1 2>&1 || true
launchctl setenv _SafeMode 1 2>&1 || true
sudo -u mobile launchctl setenv DISABLE_TWEAKS 1 2>&1 || true
sudo -u mobile launchctl setenv _MSSafeMode 1 2>&1 || true
sudo -u mobile launchctl setenv _SafeMode 1 2>&1 || true
sleep 1
sudo -u mobile uiopen 'zbra://' >/tmp/zebra-safe-open.txt 2>&1
echo "safe_uiopen_rc=$?"
cat /tmp/zebra-safe-open.txt 2>/dev/null || true
sleep 5
echo 'safe_t=5'; ps aux 2>/dev/null | grep -i '[Z]ebra' || echo absent
sleep 20
echo 'safe_t=25'; ps aux 2>/dev/null | grep -i '[Z]ebra' || echo absent
sleep 25
echo 'safe_t=50'; ps aux 2>/dev/null | grep -i '[Z]ebra' || echo absent

# Remove inherited safe-mode vars after the test.
launchctl unsetenv DISABLE_TWEAKS 2>&1 || true
launchctl unsetenv _MSSafeMode 2>&1 || true
launchctl unsetenv _SafeMode 2>&1 || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>&1 || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>&1 || true
sudo -u mobile launchctl unsetenv _SafeMode 2>&1 || true

echo '--- reports mentioning Zebra after safe test ---'
find "$CR" -type f -mmin -10 -print 2>/dev/null | while IFS= read -r f; do
  if grep -Iql 'Zebra\|xyz.willy.Zebra' "$f" 2>/dev/null; then
    echo "REPORT=$f"
    grep -Ei 'bug_type|procName|procPath|Exception Type|Termination Reason|watchdog|scene-update|jetsam|reason|code|namespace|culprit|memoryStatus' "$f" 2>/dev/null | head -n 120 || true
  fi
done | head -n 300

echo 'zebra_safe_mode_diagnostic_complete=true'
exit 0
