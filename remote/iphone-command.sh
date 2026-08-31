#!/bin/sh
set -u
export PATH=/var/jb/usr/bin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
echo ===LAUNCH_FELIX_AS_MOBILE===
URL='livecontainer://livecontainer-launch?bundle-name=com.disney.FixItFelixJr.app'
killall -9 LiveContainer LiveExec32 FixItFelixJr 2>/dev/null || true
if command -v sudo >/dev/null 2>&1; then sudo -u mobile uiopen "$URL" 2>&1; RC=$?; else su mobile -c "uiopen '$URL'" 2>&1; RC=$?; fi
echo uiopen_rc="$RC"
sleep 3
echo ===PROCESS_AFTER_3S===
ps ax | grep -E 'LiveContainer|LiveExec32|FixItFelix' | grep -v grep || true
sleep 12
echo ===PROCESS_AFTER_15S===
ps ax | grep -E 'LiveContainer|LiveExec32|FixItFelix' | grep -v grep || true
echo ===RECENT_CRASH_FILES===
find /var/mobile/Library/Logs/CrashReporter -type f -mmin -3 2>/dev/null | tail -30
echo MOBILE_LAUNCH_COMPLETE=1
