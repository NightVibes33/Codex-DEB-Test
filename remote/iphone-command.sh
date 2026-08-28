#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export DEBIAN_FRONTEND=noninteractive
PKG=com.spark.snowboard
SOURCE=/var/jb/etc/apt/sources.list.d/sparkdev.list

echo '=== IPHONE SNOWBOARD ROOTLESS REPAIR ==='
echo "captured_at=$(date 2>/dev/null)"
echo "whoami=$(whoami 2>/dev/null)"
echo "model=$(sysctl -n hw.machine 2>/dev/null) ios=$(sw_vers -productVersion 2>/dev/null)"

printf '\n===== BEFORE =====\n'
dpkg-query -W -f='${Status}\t${Package}\t${Version}\t${Architecture}\n' "$PKG" 2>/dev/null || echo 'snowboard=not-installed'
echo '-- SparkDev source entries --'
grep -RHi 'sparkdev\.me' /var/jb/etc/apt/sources.list /var/jb/etc/apt/sources.list.d 2>/dev/null || echo 'sparkdev_source=not-present'
echo '-- package candidate before source repair --'
apt-cache policy "$PKG" 2>/dev/null || true

printf '\n===== ENSURE OFFICIAL SPARKDEV SOURCE =====\n'
if ! grep -Rqi 'sparkdev\.me' /var/jb/etc/apt/sources.list /var/jb/etc/apt/sources.list.d 2>/dev/null; then
  mkdir -p /var/jb/etc/apt/sources.list.d
  printf '%s\n' 'deb https://sparkdev.me/ ./' > "$SOURCE"
  chmod 0644 "$SOURCE"
  chown root:wheel "$SOURCE" 2>/dev/null || true
  echo "added_source=$SOURCE"
else
  echo 'sparkdev_source=already-present'
fi

printf '\n===== REFRESH PACKAGE INDEX =====\n'
apt-get update 2>&1
UPDATE_RC=$?
echo "apt_update_rc=$UPDATE_RC"

echo '-- package candidate after update --'
apt-cache policy "$PKG" 2>/dev/null || true
CANDIDATE=$(apt-cache policy "$PKG" 2>/dev/null | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | head -n 1)
echo "candidate=${CANDIDATE:-none}"

if [ -z "$CANDIDATE" ] || [ "$CANDIDATE" = '(none)' ]; then
  echo 'ERROR=no SnowBoard candidate from configured sources'
  exit 2
fi

printf '\n===== INSTALL ROOTLESS SNOWBOARD =====\n'
apt-get install -y "$PKG" 2>&1
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
  grep -Ei 'Preference|TweakInject|SnowBoard|Themes|Applications' "$LIST" 2>/dev/null | head -n 250 || true
else
  echo 'snowboard_dpkg_list=MISSING'
fi

echo '-- rootless preference panes now --'
find /var/jb/Library/PreferenceLoader/Preferences -maxdepth 1 -type f -print 2>/dev/null | sort || true
find /var/jb/Library/PreferenceBundles -maxdepth 1 -type d -print 2>/dev/null | sort || true

echo '-- SnowBoard injection files --'
find /var/jb/usr/lib/TweakInject -maxdepth 1 \( -iname '*snowboard*' -o -iname '*snow*' \) -print 2>/dev/null | sort || true

echo '-- installed themes remain present --'
find /var/jb/Library/Themes -maxdepth 1 -mindepth 1 -type d -print 2>/dev/null | head -n 80 || true

printf '\n===== RELOAD SETTINGS + SPRINGBOARD =====\n'
OLD_SB=$(ps -A -o pid=,comm= 2>/dev/null | grep '/SpringBoard$' | head -n1 | tr -s ' ' | cut -d' ' -f2)
echo "springboard_pid_before=${OLD_SB:-unknown}"
killall Preferences 2>/dev/null || true
killall SpringBoard 2>/dev/null || true
sleep 5
NEW_SB=$(ps -A -o pid=,comm= 2>/dev/null | grep '/SpringBoard$' | head -n1 | tr -s ' ' | cut -d' ' -f2)
echo "springboard_pid_after=${NEW_SB:-unknown}"

echo '=== END IPHONE SNOWBOARD ROOTLESS REPAIR ==='
