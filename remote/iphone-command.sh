#!/bin/sh
set -u
export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
BUNDLE=com.nightvibes33.livecontainer
echo ===FIX_PERMISSIONS_AND_LAUNCH_FELIX===
DATA=
for meta in $(find /private/var/mobile/Containers/Data/Application -name .com.apple.mobile_container_manager.metadata.plist 2>/dev/null); do
  if plutil -p "$meta" 2>/dev/null | grep -Fq "$BUNDLE" || grep -aqF "$BUNDLE" "$meta"; then DATA="$(dirname "$meta")"; break; fi
done
[ -n "$DATA" ] || exit 81
APPS="$DATA/Documents/Applications"
FELIX="$APPS/com.disney.FixItFelixJr.app/FixItFelixJr"
chmod 755 "$FELIX" || exit 82
chown mobile:mobile "$FELIX" 2>/dev/null || true
ls -l "$FELIX"
file "$FELIX" 2>/dev/null || true
[ -x "$FELIX" ] || exit 83
echo FELIX_EXECUTABLE_READY=1
killall -9 LiveContainer LiveExec32 FixItFelixJr 2>/dev/null || true
URL='livecontainer://livecontainer-launch?bundle-name=com.disney.FixItFelixJr.app'
uiopen "$URL" || exit 84
sleep 3
echo ===PROCESS_AFTER_3S===
ps ax | grep -E 'LiveContainer|LiveExec32|FixItFelix' | grep -v grep || true
sleep 12
echo ===PROCESS_AFTER_15S===
ps ax | grep -E 'LiveContainer|LiveExec32|FixItFelix' | grep -v grep || true
echo ===RECENT_CRASH_FILES===
find /var/mobile/Library/Logs/CrashReporter -type f -mmin -3 2>/dev/null | tail -30
echo FELIX_LAUNCH_ATTEMPT_COMPLETE=1
