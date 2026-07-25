#!/bin/sh
set -eu

media='/var/mobile/Library/Application Support/Gif2Ani'
prefs='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'

version=$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)
echo "final_version=$version"
test "$version" = '3.1.3'

grep -a -q '<key>isEnabled</key><false/>' "$prefs"
test ! -e "$media/Pending.gif"
test ! -e "$media/Active.gif"
test ! -e "$media/Rejected.gif"
test ! -e "$media/load-in-progress"

bb=$(ps ax | awk '$5=="/usr/libexec/backboardd" {print $1; exit}')
test -n "$bb"
bb_env=$(ps eww -p "$bb" 2>/dev/null || true)
printf '%s\n' "$bb_env" | grep -q 'JB_PINFO_FLAGS=0x4c00082'
echo "final_backboardd=$bb"
echo final_state=gif2ani_3.1.3_racefix_installed_disabled_no_media
