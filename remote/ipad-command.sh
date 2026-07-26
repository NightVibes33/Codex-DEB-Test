#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

ROOTLESS_SH=''
for candidate in /var/jb/usr/bin/sh /var/jb/bin/sh /usr/bin/sh; do
  if [ -x "$candidate" ]; then ROOTLESS_SH="$candidate"; break; fi
done
[ -n "$ROOTLESS_SH" ] || { echo 'launcher_error=no_executable_rootless_shell'; exit 120; }

MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
WORK='/var/mobile/Library/Caches/Gif2Ani341DetachedLauncher'
SCRIPT="$WORK/gif2ani-341-detached-theme-test.sh"
LOG="$MEDIA/detached-theme-test-status.txt"
PIDFILE="$MEDIA/detached-theme-test.pid"
SCRIPT_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/main/remote/gif2ani-341-detached-theme-test.sh'

mkdir -p "$MEDIA" "$WORK"
rm -f "$SCRIPT"
curl -fL --connect-timeout 20 --max-time 120 --retry 4 --retry-delay 2 "$SCRIPT_URL" -o "$SCRIPT"
test -s "$SCRIPT"
chmod 0700 "$SCRIPT"

# Do not overlap with an existing detached proof.
if [ -f "$PIDFILE" ]; then
  OLD_PID="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "detached_test_already_running_pid=$OLD_PID"
    exit 0
  fi
fi

: > "$LOG"
chown 501:501 "$LOG" 2>/dev/null || true
chmod 0644 "$LOG" 2>/dev/null || true

nohup "$ROOTLESS_SH" "$SCRIPT" >> "$LOG" 2>&1 </dev/null &
PID=$!
printf '%s\n' "$PID" > "$PIDFILE"
chown 501:501 "$PIDFILE" 2>/dev/null || true
chmod 0644 "$PIDFILE" 2>/dev/null || true

printf 'rootless_shell=%s\n' "$ROOTLESS_SH"
printf 'detached_test_pid=%s\n' "$PID"
printf 'detached_test_log=%s\n' "$LOG"
echo 'detached_test_launched=true'
