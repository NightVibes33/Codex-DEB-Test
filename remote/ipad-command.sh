#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
D=/var/jb/usr/lib/TweakInject

echo '=== REMOVE LYNX + RESTORE NORMAL TWEAK INJECTION ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'

# Ensure no previous bisect left tweak filters staged outside TweakInject.
for B in /var/mobile/.zebra-tweak-bisect-* /var/mobile/.zebra-fast-bisect-* /var/mobile/.zebra-quick-*; do
  [ -d "$B" ] || continue
  for p in "$B"/*.plist; do
    [ -f "$p" ] && mv -f "$p" "$D/$(basename "$p")" 2>/dev/null || true
  done
  rm -rf "$B" 2>/dev/null || true
done

# Identify the real dpkg package owning Lynx.
OWNER=""
for path in /usr/lib/TweakInject/Lynx.dylib /Library/MobileSubstrate/DynamicLibraries/Lynx.dylib /var/jb/usr/lib/TweakInject/Lynx.dylib; do
  hit="$(dpkg-query -S "$path" 2>/dev/null | head -n1 | cut -d: -f1)"
  [ -n "$hit" ] && { OWNER="$hit"; break; }
done
if [ -z "$OWNER" ]; then
  for info in /var/jb/var/lib/dpkg/info/*.list /var/jb/Library/dpkg/info/*.list; do
    [ -f "$info" ] || continue
    if grep -Fq '/usr/lib/TweakInject/Lynx.dylib' "$info" 2>/dev/null || grep -Fq '/Library/MobileSubstrate/DynamicLibraries/Lynx.dylib' "$info" 2>/dev/null; then
      OWNER="$(basename "$info" .list)"
      break
    fi
  done
fi

echo "lynx_owner_package=${OWNER:-not-found}"
echo '--- matching installed packages before removal ---'
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null | grep -i lynx || true
ls -l "$D/Lynx.plist" "$D/Lynx.dylib" "$D/LynxCarPlay.plist" "$D/LynxCarPlay.dylib" 2>/dev/null || true

REMOVE_RC=0
if [ -n "$OWNER" ]; then
  echo "removing_package=$OWNER"
  DEBIAN_FRONTEND=noninteractive apt-get remove -y "$OWNER"
  REMOVE_RC=$?
  echo "apt_remove_rc=$REMOVE_RC"
  if [ "$REMOVE_RC" -ne 0 ]; then
    dpkg --remove "$OWNER"
    REMOVE_RC=$?
    echo "dpkg_remove_rc=$REMOVE_RC"
  fi
else
  echo 'ERROR=Could not resolve Lynx owning package; refusing to fake an uninstall.'
  exit 2
fi

# Finish any package configuration left pending by removal.
dpkg --configure -a 2>&1 | tail -n 30 || true

echo '--- Lynx verification after removal ---'
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' 2>/dev/null | grep -i lynx || true
for f in "$D/Lynx.plist" "$D/Lynx.dylib" "$D/LynxCarPlay.plist" "$D/LynxCarPlay.dylib"; do
  if [ -e "$f" ] || [ -L "$f" ]; then echo "LYNX_FILE_REMAINS=$f"; else echo "lynx_file_absent=$f"; fi
done

# Re-enable normal ElleKit/tweak injection globally by clearing all test safe-mode vars.
launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
launchctl unsetenv _MSSafeMode 2>/dev/null || true
sudo -u mobile launchctl unsetenv DISABLE_TWEAKS 2>/dev/null || true
sudo -u mobile launchctl unsetenv _MSSafeMode 2>/dev/null || true

echo '--- injection environment ---'
echo "root_DISABLE_TWEAKS=$(launchctl getenv DISABLE_TWEAKS 2>/dev/null)"
echo "root_MSSafeMode=$(launchctl getenv _MSSafeMode 2>/dev/null)"
echo "mobile_DISABLE_TWEAKS=$(sudo -u mobile launchctl getenv DISABLE_TWEAKS 2>/dev/null)"
echo "mobile_MSSafeMode=$(sudo -u mobile launchctl getenv _MSSafeMode 2>/dev/null)"

# Launch Zebra NORMALLY, with tweak injection enabled, and verify beyond the old watchdog window.
killall -9 Zebra 2>/dev/null || true
sleep 2
sudo -u mobile uiopen 'zbra://' >/tmp/zebra-normal-after-lynx.txt 2>&1 || true
cat /tmp/zebra-normal-after-lynx.txt 2>/dev/null || true
zpid(){ ps ax 2>/dev/null | awk '/[Z]ebra.app\/Zebra/{print $1; exit}'; }
sleep 5; echo "zebra_t5_pid=$(zpid)"
sleep 20; echo "zebra_t25_pid=$(zpid)"
sleep 20; FINAL="$(zpid)"; echo "zebra_t45_pid=${FINAL:-absent}"

if [ -n "$FINAL" ]; then
  echo 'NORMAL_INJECTION_ZEBRA_TEST=PASS'
else
  echo 'NORMAL_INJECTION_ZEBRA_TEST=FAIL'
fi

echo "lynx_remove_rc=$REMOVE_RC"
echo 'lynx_removal_and_injection_restore_complete=true'
exit "$REMOVE_RC"
