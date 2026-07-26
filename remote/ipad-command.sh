#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
LOG="$MEDIA/detached-theme-test-status.txt"
PIDFILE="$MEDIA/detached-theme-test.pid"
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
ACTIVE="$MEDIA/Active.gif"
RUNTIME="$MEDIA/runtime-status.plist"

printf '%s\n' '=== Gif2Ani 3.4.1 detached proof reader ==='
printf 'verified_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'installed_version=%s\n' "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani 2>/dev/null || true)"
printf 'active_sha256=%s\n' "$(if [ -f "$ACTIVE" ]; then sha256sum "$ACTIVE" | awk '{print $1}'; else echo MISSING; fi)"
printf 'preferences_sha256=%s\n' "$(if [ -f "$PREFS" ]; then sha256sum "$PREFS" | awk '{print $1}'; else echo MISSING; fi)"

PID=''
if [ -f "$PIDFILE" ]; then PID="$(cat "$PIDFILE" 2>/dev/null || true)"; fi
printf 'detached_pid=%s\n' "$PID"
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then echo 'detached_process=running'; else echo 'detached_process=finished'; fi

if [ -f "$RUNTIME" ]; then
  python3 - "$RUNTIME" <<'PY'
import json,plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: data=plistlib.load(f)
    print('current_runtime='+json.dumps(data,sort_keys=True,default=str))
except Exception as e:
    print('current_runtime_error='+repr(e))
PY
else
  echo 'current_runtime=missing'
fi

echo '=== detached test log ==='
if [ -f "$LOG" ]; then
  cat "$LOG"
else
  echo 'detached_test_log=missing'
  exit 91
fi

if grep -q '^detached_theme_test=success$' "$LOG" && \
   grep -q '^runtime_themes_passed=3$' "$LOG" && \
   grep -q '^active_state_restored=true$' "$LOG"; then
  echo 'detached_proof_reader=success'
  exit 0
fi

if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
  echo 'detached_proof_reader=still_running'
  exit 0
fi

echo 'detached_proof_reader=failed_or_incomplete'
exit 92
