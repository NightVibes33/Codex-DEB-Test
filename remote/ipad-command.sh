#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

echo '=== TWEAKMEDIC INSTALLED DEVICE DIAGNOSTIC ==='
printf 'started='; date '+%Y-%m-%d %H:%M:%S %z'

echo '--- package ---'
dpkg-query -W -f='package=${Package}\nversion=${Version}\nstatus=${Status}\narch=${Architecture}\n' com.nightvibes33.tweakmedic 2>&1
DPKG_RC=$?
echo "dpkg_query_rc=$DPKG_RC"
dpkg -L com.nightvibes33.tweakmedic 2>/dev/null | sed -n '1,160p'

echo '--- expected payload ---'
for p in \
  /var/jb/Applications/TweakMedic.app/TweakMedic \
  /var/jb/Applications/TweakMedic.app/Info.plist \
  /var/jb/usr/libexec/tweakmedicd \
  /var/jb/usr/bin/tweakmedicctl \
  /var/jb/Library/LaunchDaemons/com.nightvibes33.tweakmedicd.plist \
  /var/jb/Library/PreferenceBundles/TweakMedicPrefs.bundle/TweakMedicPrefs \
  /var/jb/Library/PreferenceBundles/TweakMedicPrefs.bundle/Root.plist \
  /var/jb/Library/PreferenceLoader/Preferences/TweakMedicPrefs.plist; do
  if [ -e "$p" ] || [ -L "$p" ]; then
    echo "PRESENT=$p"
    ls -ld "$p" 2>/dev/null
  else
    echo "MISSING=$p"
  fi
done

echo '--- launch daemon ---'
launchctl print system/com.nightvibes33.tweakmedicd 2>&1 | sed -n '1,120p'
PRINT_BEFORE=$?
echo "launchctl_print_before_rc=$PRINT_BEFORE"
launchctl bootstrap system /var/jb/Library/LaunchDaemons/com.nightvibes33.tweakmedicd.plist 2>&1
BOOTSTRAP_RC=$?
echo "bootstrap_rc=$BOOTSTRAP_RC"
launchctl kickstart -k system/com.nightvibes33.tweakmedicd 2>&1
KICK_RC=$?
echo "kickstart_rc=$KICK_RC"
sleep 2
launchctl print system/com.nightvibes33.tweakmedicd 2>&1 | sed -n '1,140p'
echo '--- daemon process/socket/log ---'
ps ax 2>/dev/null | grep '[t]weakmedicd' || true
ls -l /var/run/tweakmedicd.sock 2>&1 || true
tail -n 100 /var/mobile/Library/TweakMedic/daemon.log 2>&1 || true

echo '--- CLI ---'
/var/jb/usr/bin/tweakmedicctl ping 2>&1
PING_RC=$?
echo "ping_rc=$PING_RC"
/var/jb/usr/bin/tweakmedicctl restore 2>&1
echo "restore_rc=$?"
/var/jb/usr/bin/tweakmedicctl snapshot 2>&1 | sed -n '1,120p'
echo "snapshot_rc=${PIPESTATUS:-unknown}"

echo '--- UI registration/launch ---'
/var/jb/usr/bin/uicache -p /var/jb/Applications/TweakMedic.app 2>&1 || /var/jb/usr/bin/uicache -a 2>&1 || true
sudo -u mobile uiopen 'tweakmedic://' 2>&1
UIOPEN_RC=$?
echo "uiopen_rc=$UIOPEN_RC"
sleep 5
ps ax 2>/dev/null | grep '[T]weakMedic.app/TweakMedic' || true
APP_PID="$(ps ax 2>/dev/null | awk '/[T]weakMedic.app\/TweakMedic/{print $1; exit}')"
echo "app_pid=${APP_PID:-absent}"

echo '--- preferences registration ---'
killall -9 Preferences 2>/dev/null || true
ls -la /var/jb/Library/PreferenceBundles/TweakMedicPrefs.bundle 2>&1 || true
ls -l /var/jb/Library/PreferenceLoader/Preferences/TweakMedicPrefs.plist 2>&1 || true

echo "TWEAKMEDIC_DIAGNOSTIC_COMPLETE=true"
exit 0
