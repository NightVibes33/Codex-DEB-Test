#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

URL='https://raw.githubusercontent.com/NightVibes33/Dark-Boot/main/release-packages/Gif2Ani-3.5.3-immutable-springy-fix.deb'
EXPECTED_SHA='ea4e5ac0c565587e9e9a36084a7a788128c2167cb1ec6b880a1194f974297a3d'
TMP='/tmp/Gif2Ani-3.5.3-immutable-springy-fix.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
PREVIEWS="$BUNDLE/ThemePreviews"

printf '%s\n' '=== Install and persist-verify Gif2Ani 3.5.3 ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

rm -f "$TMP"
trap 'rm -f "$TMP"' EXIT INT TERM
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 240 -o "$TMP" "$URL"
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'download_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"
test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.3'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.3'

test -s "$PREFS_BIN"
test -s "$TWEAK_BIN"
test "$(find "$PREVIEWS" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')" = '102'
strings "$PREFS_BIN" | grep -Fq 'raw.githubusercontent.com/VirenMohindra/CydiaRepo/'
echo 'immutable_springy_marker=passed'

killall -9 Preferences 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 12
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_12s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.3'

printf 'status_file_version='; awk '/^Package: com.nightvibes33.gif2ani$/{found=1; next} found && /^Version:/{print $2; exit}' /var/jb/Library/dpkg/status 2>/dev/null || true
printf 'prefs_bundle_mtime='; stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%SZ' "$BUNDLE" 2>/dev/null || true
printf 'tweak_binary_sha256='; sha256sum "$TWEAK_BIN" | awk '{print $1}'
printf 'prefs_binary_sha256='; sha256sum "$PREFS_BIN" | awk '{print $1}'
echo 'gif2ani_353_persistent_install=success'
