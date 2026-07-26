#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

RELEASE_COMMIT='52f1cf4f8d0082569e8dab9dfeac8a1123960a32'
RELEASE_URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.8-sha-bound-identity.deb"
RELEASE_SHA='0d2953840e63191e221ac0bf9bd682c001ac77c064a40cf41c7808504b3a2d44'
TMP='/tmp/Gif2Ani-3.5.8-sha-bound-identity.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
ROOT_PLIST="$BUNDLE/Root.plist"
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
OPEN_ROOT="$MEDIA_ROOT/OpenThemeLibrary"
DIAGNOSTIC="$MEDIA_ROOT/LastPackageVerification.plist"
WORK='/tmp/gif2ani-358-ipad-verify'

printf '%s\n' '=== Install and verify Gif2Ani 3.5.8 on iPad ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

rm -rf "$WORK"
mkdir -p "$WORK"
rm -f "$TMP"
trap 'rm -rf "$WORK"; rm -f "$TMP"' EXIT INT TERM

EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$TMP" --write-out '%{url_effective}' "$RELEASE_URL")"
printf 'release_effective_url=%s\n' "$EFFECTIVE"
test "$EFFECTIVE" = "$RELEASE_URL"
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'release_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$RELEASE_SHA"
test "$(dpkg-deb -f "$TMP" Package | tr -d '\r\n')" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version | tr -d '\r\n')" = '3.5.8'
test "$(dpkg-deb -f "$TMP" Architecture | tr -d '\r\n')" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.8'

test -s "$ROOT_PLIST"
test -s "$PREFS_BIN"
test -s "$SPRINGY_CATALOG"
test -s "$SNOWBOARD_CATALOG"
grep -Fq 'GIF2ANI 3.5.8' "$ROOT_PLIST"
grep -Fq '274-THEME ANIMATION GALLERY' "$ROOT_PLIST"
strings "$PREFS_BIN" | grep -Fq 'sha256-bound-package-identity-fallback-v358'
strings "$PREFS_BIN" | grep -Fq 'strict-package-id-mismatch'
strings "$PREFS_BIN" | grep -Fq 'LastPackageVerification.plist'
strings "$PREFS_BIN" | grep -Fq 'The downloaded DEB byte count does not match the verified catalog.'
echo 'installed_358_binary_and_ui=passed'

python3 - "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" "$WORK/tests.tsv" <<'PY'
import json, pathlib, sys
springy=json.loads(pathlib.Path(sys.argv[1]).read_text())
snowboard=json.loads(pathlib.Path(sys.argv[2]).read_text())
assert springy['count'] == len(springy['themes']) == 48
assert snowboard['packageCount'] == 7
assert snowboard['count'] == len(snowboard['themes']) == 160
assert len({x['identifier'] for x in snowboard['themes']}) == 160
sp=next(x for x in springy['themes'] if x['name'] == 'Gameboy Advance')
sb=next(x for x in snowboard['themes'] if x['package'] == 'com.thwlfu.cakrespring')
rows=[]
for kind, theme in [('springy',sp),('snowboard',sb)]:
    fields=[kind,theme['package'],str(theme['bytes']),theme['sha256'],theme['downloadURL'],theme.get('archiveSubpath',''),theme['name']]
    assert all('\t' not in value and '\n' not in value for value in fields)
    rows.append('\t'.join(fields))
pathlib.Path(sys.argv[3]).write_text('\n'.join(rows)+'\n')
print('installed_springy_themes=48')
print('installed_snowboard_packages=7')
print('installed_snowboard_themes=160')
print('installed_gallery_total=274')
PY

mkdir -p "$MEDIA_ROOT" "$OPEN_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
find "$MEDIA_ROOT" -type d -exec chmod 0755 {} +
find "$MEDIA_ROOT" -type f -exec chmod 0644 {} +
find "$OPEN_ROOT" -maxdepth 1 -type d -name '.download-*' -exec rm -rf {} + 2>/dev/null || true
rm -f "$DIAGNOSTIC"

WRITE_TEST="$OPEN_ROOT/.gif2ani-mobile-write-test"
rm -f "$WRITE_TEST"
sudo -u mobile sh -c "printf mobile-write-ok > '$WRITE_TEST'"
test "$(cat "$WRITE_TEST")" = 'mobile-write-ok'
test "$(ls -dn "$WRITE_TEST" | awk '{print $3}')" = '501'
rm -f "$WRITE_TEST"
echo 'settings_download_cache_permission=passed'

TAB="$(printf '\t')"
INDEX=0
while IFS="$TAB" read -r KIND EXPECTED_PACKAGE EXPECTED_BYTES EXPECTED_SHA DOWNLOAD_URL ARCHIVE_SUBPATH DISPLAY_NAME; do
  INDEX=$((INDEX + 1))
  CASE_DIR="$WORK/$KIND"
  DEB="$CASE_DIR/theme.deb"
  EXTRACTED="$CASE_DIR/extracted"
  mkdir -p "$CASE_DIR" "$EXTRACTED"
  chown -R mobile:mobile "$CASE_DIR"

  EFFECTIVE_URL="$(sudo -u mobile curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$DEB" --write-out '%{url_effective}' "$DOWNLOAD_URL")"
  printf '%s_effective_url=%s\n' "$KIND" "$EFFECTIVE_URL"
  ACTUAL_BYTES="$(wc -c < "$DEB" | tr -d ' ')"
  ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
  ACTUAL_PACKAGE="$(dpkg-deb -f "$DEB" Package | tr -d '\r\n')"
  test "$ACTUAL_BYTES" = "$EXPECTED_BYTES"
  test "$ACTUAL_SHA" = "$EXPECTED_SHA"
  test "$ACTUAL_PACKAGE" = "$EXPECTED_PACKAGE"
  test "$(ls -dn "$DEB" | awk '{print $3}')" = '501'
  dpkg-deb -x "$DEB" "$EXTRACTED"
  if [ -n "$ARCHIVE_SUBPATH" ]; then
    test -d "$EXTRACTED/$ARCHIVE_SUBPATH"
  else
    MEDIA_COUNT="$(find "$EXTRACTED" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
    test "$MEDIA_COUNT" -ge 1
  fi
  printf '%s_pinned_identity=passed|%s|%s|bytes=%s|sha256=%s\n' "$KIND" "$EXPECTED_PACKAGE" "$DISPLAY_NAME" "$ACTUAL_BYTES" "$ACTUAL_SHA"
done < "$WORK/tests.tsv"
test "$INDEX" = '2'

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 6
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_6s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.8'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
printf 'gallery_label='; grep -o '[0-9]*-THEME ANIMATION GALLERY' "$ROOT_PLIST" | head -n 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi

echo 'gif2ani_358_install=success'
echo 'gif2ani_358_sha_bound_identity=success'
echo 'gif2ani_358_springy_gameboy_advance=success'
echo 'gif2ani_358_snowboard_sample=success'
echo 'gif2ani_358_gallery_total_274=success'
# trigger_refresh=2026-07-26T17:42:00Z
