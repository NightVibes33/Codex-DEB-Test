#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export DEBIAN_FRONTEND=noninteractive
PKG=com.spark.snowboard

echo '=== IPHONE SNOWBOARD ROOTLESS REPAIR ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== VERIFY OFFICIAL SPARKDEV CANDIDATE =====\n'
grep -RHi 'sparkdev\.me' /var/jb/etc/apt/sources.list /var/jb/etc/apt/sources.list.d 2>/dev/null || true
apt-cache policy "$PKG" 2>/dev/null || true
CANDIDATE=$(apt-cache policy "$PKG" 2>/dev/null | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | head -n 1)
echo "candidate=${CANDIDATE:-none}"
if [ -z "$CANDIDATE" ] || [ "$CANDIDATE" = '(none)' ]; then
  echo 'ERROR=no cached SnowBoard candidate from SparkDev'
  exit 2
fi

printf '\n===== INSTALL ONLY SNOWBOARD + REQUIRED DEPENDENCIES =====\n'
# SparkDev is a legacy unsigned jailbreak repository. Scope the authentication
# exception to this explicit SnowBoard install rather than weakening APT globally.
apt-get install -y --allow-unauthenticated "$PKG" 2>&1
INSTALL_RC=$?
echo "apt_install_rc=$INSTALL_RC"
if [ "$INSTALL_RC" -ne 0 ]; then
  exit "$INSTALL_RC"
fi

printf '\n===== VERIFY PACKAGE =====\n'
dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\tDepends=${Depends}\n' "$PKG" 2>/dev/null || true
LIST="/var/jb/var/lib/dpkg/info/${PKG}.list"
if [ -f "$LIST" ]; then
  echo '-- SnowBoard installed files relevant to prefs/injection/themes --'
  grep -Ei 'Preference|TweakInject|SnowBoard|Themes|Applications' "$LIST" 2>/dev/null | head -n 300 || true
else
  echo 'snowboard_dpkg_list=MISSING'
fi

printf '\n===== VERIFY SETTINGS PANE =====\n'
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -print 2>/dev/null | sort || true
find /var/jb/Library/PreferenceBundles -maxdepth 1 -type d -print 2>/dev/null | sort || true

printf '\n===== VERIFY SNOWBOARD INJECTION =====\n'
find /var/jb/usr/lib/TweakInject -maxdepth 1 \( -iname '*snowboard*' -o -iname '*snow*' \) -print 2>/dev/null | sort || true

printf '\n===== VERIFY EXISTING THEMES =====\n'
find /var/jb/Library/Themes -maxdepth 1 -mindepth 1 -type d -print 2>/dev/null | sort | head -n 120 || true

printf '\n===== RELOAD SETTINGS + SPRINGBOARD =====\n'
OLD_SB=$(pgrep -x SpringBoard 2>/dev/null | head -n1)
echo "springboard_pid_before=${OLD_SB:-unknown}"
killall Preferences 2>/dev/null || true
killall SpringBoard 2>/dev/null || true
sleep 6
NEW_SB=$(pgrep -x SpringBoard 2>/dev/null | head -n1)
echo "springboard_pid_after=${NEW_SB:-unknown}"
if [ -z "$NEW_SB" ]; then
  ps -A -o pid=,comm= 2>/dev/null | grep -i SpringBoard || true
fi

echo '=== END IPHONE SNOWBOARD ROOTLESS REPAIR ==='
