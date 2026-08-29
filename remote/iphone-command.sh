#!/bin/sh
set +e
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BUNDLE='com.nightvibes.app.threeoneosfive1'
REAL_IPA='/var/mobile/Media/3105-dopamine-launchable.ipa'
REAL_SHA='9944eaec3c8ab6ea17b962b89bafafd0cbeae1fe7117563bdf09cb420867a2a2'
UICACHE=/var/jb/usr/bin/uicache

echo '=== RESTORE VERIFIED REAL 3105 2.0 BUILD 8 ==='
echo "device_time=$(date 2>/dev/null)"
uname -a 2>/dev/null || true

hash_file() {
  f="$1"
  [ -f "$f" ] || { echo missing; return; }
  if command -v sha256sum >/dev/null 2>&1; then set -- $(sha256sum "$f" 2>/dev/null); else set -- $(shasum -a 256 "$f" 2>/dev/null); fi
  echo "$1"
}

find_helper() {
  for p in /var/jb/usr/bin/trollstorehelper /var/jb/Applications/TrollStore.app/trollstorehelper /Applications/TrollStore.app/trollstorehelper /var/containers/Bundle/Application/*/*.app/trollstorehelper; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
}

find_pid() {
  if command -v pidof >/dev/null 2>&1; then
    P="$(pidof 3105 2>/dev/null || true)"; set -- $P; [ -n "${1:-}" ] && { echo "$1"; return; }
  fi
  ps ax 2>/dev/null | while read pid rest; do case "$rest" in *'/3105.app/3105'*) echo "$pid"; break;; esac; done
}

for p in $(pidof 3105 2>/dev/null || true); do kill -9 "$p" 2>/dev/null || true; done
killall -9 3105 2>/dev/null || true
sleep 2

GOT="$(hash_file "$REAL_IPA")"
echo "real_ipa_sha=$GOT"
[ "$GOT" = "$REAL_SHA" ] || { echo REAL_3105_IPA_HASH_MISMATCH=1; exit 80; }
echo REAL_3105_IPA_HASH_MATCH=1

H="$(find_helper)"
echo "trollstorehelper=$H"
[ -n "$H" ] || exit 81

"$H" install force "$REAL_IPA" 2>&1
IRC=$?
echo "install_rc=$IRC"
[ "$IRC" -eq 0 ] || exit 82
"$H" refresh 2>&1 || true
sleep 6

LINE="$("$UICACHE" -l 2>&1 | grep -F "$BUNDLE" | head -n 1)"
echo "registration=$LINE"
APP="${LINE#* : }"
echo "registered_path=$APP"
[ -x "$APP/3105" ] || exit 83

printf '\n=== VERIFY REAL 3105 EXECUTABLE ===\n'
REAL_SYMBOLS=0
if command -v strings >/dev/null 2>&1; then
  strings "$APP/3105" 2>/dev/null | grep -F 'ThreeOneOSFiveApp' >/dev/null && echo THREEONEOSFIVE_APP_PRESENT=1 || echo THREEONEOSFIVE_APP_PRESENT=0
  strings "$APP/3105" 2>/dev/null | grep -F 'PackageRepositoryStore' >/dev/null && echo REPOSITORY_STORE_PRESENT=1 || echo REPOSITORY_STORE_PRESENT=0
  strings "$APP/3105" 2>/dev/null | grep -F 'https://raw.githubusercontent.com/YangJiiii/3105-repo/main/sources.json' >/dev/null && echo OFFICIAL_REPO_URL_PRESENT=1 || echo OFFICIAL_REPO_URL_PRESENT=0
  if strings "$APP/3105" 2>/dev/null | grep -F 'ThreeOneOSFiveApp' >/dev/null \
    && strings "$APP/3105" 2>/dev/null | grep -F 'PackageRepositoryStore' >/dev/null \
    && strings "$APP/3105" 2>/dev/null | grep -F 'https://raw.githubusercontent.com/YangJiiii/3105-repo/main/sources.json' >/dev/null; then REAL_SYMBOLS=1; fi
else
  grep -a -F 'ThreeOneOSFiveApp' "$APP/3105" >/dev/null 2>&1 && echo THREEONEOSFIVE_APP_PRESENT=1 || echo THREEONEOSFIVE_APP_PRESENT=0
  grep -a -F 'PackageRepositoryStore' "$APP/3105" >/dev/null 2>&1 && echo REPOSITORY_STORE_PRESENT=1 || echo REPOSITORY_STORE_PRESENT=0
  grep -a -F 'https://raw.githubusercontent.com/YangJiiii/3105-repo/main/sources.json' "$APP/3105" >/dev/null 2>&1 && echo OFFICIAL_REPO_URL_PRESENT=1 || echo OFFICIAL_REPO_URL_PRESENT=0
  if grep -a -F 'ThreeOneOSFiveApp' "$APP/3105" >/dev/null 2>&1 \
    && grep -a -F 'PackageRepositoryStore' "$APP/3105" >/dev/null 2>&1 \
    && grep -a -F 'https://raw.githubusercontent.com/YangJiiii/3105-repo/main/sources.json' "$APP/3105" >/dev/null 2>&1; then REAL_SYMBOLS=1; fi
fi

echo "real_3105_symbols=$REAL_SYMBOLS"
[ "$REAL_SYMBOLS" -eq 1 ] || exit 84

if [ -x /var/jb/usr/bin/ldid ]; then
  /var/jb/usr/bin/ldid -e "$APP/3105" 2>/dev/null | grep -E 'platform-application|MobileContainerManager.allowed|security.no-sandbox' || true
fi

echo REAL_3105_RESTORED=1
exit 0
