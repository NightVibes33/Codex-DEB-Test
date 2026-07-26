#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
OPEN_ROOT="$MEDIA_ROOT/OpenThemeLibrary"
REMOTE_ROOT="$MEDIA_ROOT/RemoteThemes"
PACKS_ROOT="$MEDIA_ROOT/Packs"
ROLLBACK_ROOT="$MEDIA_ROOT/Rollbacks"
TEST_FILE="$OPEN_ROOT/.mobile-write-test"

printf '%s\n' '=== Repair Gif2Ani gallery download permissions ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'gif2ani_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

mkdir -p "$MEDIA_ROOT" "$OPEN_ROOT" "$REMOTE_ROOT" "$PACKS_ROOT" "$ROLLBACK_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
find "$MEDIA_ROOT" -type d -exec chmod 0755 {} +
find "$MEDIA_ROOT" -type f -exec chmod 0644 {} +

echo '--- ownership_after ---'
ls -ld "$MEDIA_ROOT" "$OPEN_ROOT" "$REMOTE_ROOT" "$PACKS_ROOT" "$ROLLBACK_ROOT"

rm -f "$TEST_FILE"
if command -v sudo >/dev/null 2>&1; then
  sudo -u mobile sh -c "printf mobile-write-ok > '$TEST_FILE'"
else
  su mobile -c "printf mobile-write-ok > '$TEST_FILE'"
fi
test "$(cat "$TEST_FILE")" = 'mobile-write-ok'
OWNER_UID="$(ls -dn "$TEST_FILE" | awk '{print $3}')"
printf 'mobile_write_test_uid=%s\n' "$OWNER_UID"
test "$OWNER_UID" = '501'
rm -f "$TEST_FILE"

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
fi

echo 'gif2ani_download_cache_owner=mobile'
echo 'gif2ani_download_permission_repair=success'
