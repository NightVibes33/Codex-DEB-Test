#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

SCRIPT_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/main/remote/gif2ani-341-runtime-retest.sh'
SCRIPT='/var/mobile/Library/Caches/gif2ani-341-runtime-retest.sh'
rm -f "$SCRIPT"
curl -fL --connect-timeout 20 --max-time 120 --retry 4 --retry-delay 2 "$SCRIPT_URL" -o "$SCRIPT"
test -s "$SCRIPT"
chmod 0700 "$SCRIPT"
SHELL_PATH="$(command -v sh || true)"
[ -n "$SHELL_PATH" ] || SHELL_PATH='/var/jb/usr/bin/sh'
exec "$SHELL_PATH" "$SCRIPT"
