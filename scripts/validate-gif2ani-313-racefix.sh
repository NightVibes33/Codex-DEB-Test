#!/bin/sh
set -eu

media='/var/mobile/Library/Application Support/Gif2Ani'
prefs='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
deb='/var/mobile/Media/Gif2Ani-3.1.3-racefix.deb'
testgif='/var/mobile/Media/Gif2Ani-84-frame-racefix.gif'
marker='/var/mobile/Media/gif2ani-313-racefix.marker'
evidence='/var/mobile/Media/gif2ani-313-racefix-evidence.plist'

backboard_pid() {
  ps ax | awk '$5=="/usr/libexec/backboardd" {print $1; exit}'
}

springboard_pid() {
  ps ax | awk '$5=="/System/Library/CoreServices/SpringBoard.app/SpringBoard" {print $1; exit}'
}

wait_new_pid() {
  kind="$1"
  old="$2"
  for n in $(seq 1 60); do
    if [ "$kind" = backboardd ]; then now=$(backboard_pid); else now=$(springboard_pid); fi
    if [ -n "$now" ] && [ "$now" != "$old" ]; then
      echo "$now"
      return 0
    fi
    sleep 1
  done
  return 1
}

write_disabled() {
  cat > "$prefs" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>isEnabled</key><false/>
  <key>pendingReady</key><false/>
  <key>imageTransformation</key><string>resizeAspect</string>
  <key>customLoop</key><real>-1</real>
  <key>customDuration</key><real>-1</real>
  <key>backgroundColor</key><string>#000000</string>
</dict></plist>
PLIST
  chown mobile:mobile "$prefs" 2>/dev/null || true
  chmod 0644 "$prefs" 2>/dev/null || true
}

write_enabled() {
  cat > "$prefs" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>isEnabled</key><true/>
  <key>pendingReady</key><false/>
  <key>imageTransformation</key><string>resizeAspect</string>
  <key>customLoop</key><real>-1</real>
  <key>customDuration</key><real>-1</real>
  <key>backgroundColor</key><string>#000000</string>
</dict></plist>
PLIST
  chown mobile:mobile "$prefs"
  chmod 0644 "$prefs"
}

restart_backboard() {
  old=$(backboard_pid)
  /var/jb/usr/bin/killall -9 backboardd 2>/dev/null || killall -9 backboardd 2>/dev/null || true
  wait_new_pid backboardd "$old"
}

cleanup() {
  set +e
  echo '=== MANDATORY CLEANUP ==='
  write_disabled
  rm -f "$media/Pending.gif" "$media/Active.gif" "$media/Rejected.gif" \
        "$media/load-in-progress" "$media/pending-metadata.plist"
  cleanup_bb=$(restart_backboard 2>/dev/null || true)
  echo "cleanup_backboardd=$cleanup_bb"
  sleep 7
  rm -f "$deb" "$testgif"
}
trap cleanup EXIT

echo '=== PRECHECK ==='
initial_bb=$(backboard_pid)
initial_sb=$(springboard_pid)
test -n "$initial_bb"
test -n "$initial_sb"
initial_env=$(ps eww -p "$initial_bb" 2>/dev/null || true)
echo "initial_backboardd=$initial_bb"
echo "initial_springboard=$initial_sb"
echo "initial_backboardd_env=$initial_env"
printf '%s\n' "$initial_env" | grep -q 'JB_PINFO_FLAGS=0x4c00082'

echo '=== INSTALL RACE-FIXED 3.1.3 DISABLED ==='
mkdir -p "$media"
chown mobile:mobile "$media"
chmod 0755 "$media"
rm -f "$media/Pending.gif" "$media/Active.gif" "$media/Rejected.gif" \
      "$media/load-in-progress" "$media/runtime-status.plist" \
      "$media/pending-metadata.plist" "$evidence"
write_disabled
dpkg -i "$deb"
installed=$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)
echo "installed_version=$installed"
test "$installed" = '3.1.3'
disabled_bb=$(restart_backboard)
echo "disabled_backboardd=$disabled_bb"
sleep 8
cat "$media/runtime-status.plist"
grep -a -q 'tweak-loaded-no-media-decode' "$media/runtime-status.plist"
disabled_env=$(ps eww -p "$disabled_bb" 2>/dev/null || true)
printf '%s\n' "$disabled_env" | grep -q 'JB_PINFO_FLAGS=0x4c00082'

echo '=== PREPARE ENABLED 84-FRAME TEST ==='
cp "$testgif" "$media/Active.gif"
chown mobile:mobile "$media/Active.gif"
chmod 0644 "$media/Active.gif"
write_enabled
enabled_bb=$(restart_backboard)
echo "enabled_backboardd=$enabled_bb"
sleep 8
enabled_env=$(ps eww -p "$enabled_bb" 2>/dev/null || true)
echo "enabled_backboardd_env=$enabled_env"
printf '%s\n' "$enabled_env" | grep -q 'JB_PINFO_FLAGS=0x4c00082'
cat "$media/runtime-status.plist"
grep -a -q 'tweak-loaded-no-media-decode' "$media/runtime-status.plist"
test -f "$media/Active.gif"

echo '=== TRIGGER SPRINGBOARD-ONLY RESPRING ==='
touch "$marker"
old_sb=$(springboard_pid)
/var/jb/usr/bin/killall -9 SpringBoard 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
new_sb=$(wait_new_pid SpringBoard "$old_sb")
echo "old_springboard=$old_sb"
echo "new_springboard=$new_sb"
sleep 18

echo '=== PHYSICAL RESULT ==='
cat "$media/runtime-status.plist" 2>/dev/null || echo runtime_status=missing
test -f "$media/runtime-status.plist"
cp "$media/runtime-status.plist" "$evidence"
grep -a -q 'custom-animation-stable' "$media/runtime-status.plist"
grep -A 2 '<key>sourceFrames</key>' "$media/runtime-status.plist" | grep -q '<integer>84</integer>'
grep -A 2 '<key>decodedFrames</key>' "$media/runtime-status.plist" | grep -q '<integer>24</integer>'
grep -A 2 '<key>frameCount</key>' "$media/runtime-status.plist" | grep -q '<integer>24</integer>'
grep -A 2 '<key>animationPending</key>' "$media/runtime-status.plist" | grep -q '<false/>'
test -f "$media/Active.gif"
test ! -e "$media/Rejected.gif"
test ! -e "$media/load-in-progress"
crashes=$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \
  \( -name 'backboardd-*.ips' -o -name 'SpringBoard-*.ips' \) \
  -newer "$marker" -print 2>/dev/null | wc -l | tr -d ' ')
echo "new_crash_reports=$crashes"
test "$crashes" = 0
echo physical_result=gif2ani_3.1.3_racefix_84_frame_success
