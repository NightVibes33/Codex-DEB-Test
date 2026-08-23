#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

RELEASE_COMMIT='267cb8e16d9c2bb30968e889a94e6bfc921e76f9'
RELEASE_URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.7-shared-verifier-fix.deb"
RELEASE_SHA='7b02279eb5a6146cd5a3835b723cf6bb2d4434b5327f4bb51af17cf46fd4b04f'
TMP='/tmp/Gif2Ani-3.5.7-shared-verifier-fix.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
ROOT_PLIST="$BUNDLE/Root.plist"
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
OPEN_ROOT="$MEDIA_ROOT/OpenThemeLibrary"
WORK='/tmp/gif2ani-357-package-id-test'

printf '%s\n' '=== Install Gif2Ani 3.5.7 and verify shared Springy/SnowBoard package-ID fix ==='
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
test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.7'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.7'

test -s "$ROOT_PLIST"
test -s "$PREFS_BIN"
test -s "$SPRINGY_CATALOG"
test -s "$SNOWBOARD_CATALOG"
grep -Fq 'GIF2ANI 3.5.7' "$ROOT_PLIST"
grep -Fq '274-THEME ANIMATION GALLERY' "$ROOT_PLIST"
strings "$PREFS_BIN" | grep -Fq 'gif2ani-stderr-'
strings "$PREFS_BIN" | grep -Fq 'Expected %@, received %@.'
echo 'installed_357_binary_and_ui=passed'

python3 - "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" "$WORK/tests.tsv" <<'PY'
import json, pathlib, sys
springy=json.loads(pathlib.Path(sys.argv[1]).read_text())
snowboard=json.loads(pathlib.Path(sys.argv[2]).read_text())
assert springy['count'] == len(springy['themes']) == 48
assert snowboard['packageCount'] == 7
assert snowboard['count'] == len(snowboard['themes']) == 160
sp=next(x for x in springy['themes'] if x['name'] == 'Gameboy Advance')
sb=next(x for x in snowboard['themes'] if x['package'] == 'com.thwlfu.cakrespring')
rows=[]
for kind, x in [('springy', sp), ('snowboard', sb)]:
    fields=[kind, x['package'], str(x['bytes']), x['sha256'], x['downloadURL'], x.get('archiveSubpath',''), x['name']]
    assert all('\t' not in value and '\n' not in value for value in fields)
    rows.append('\t'.join(fields))
pathlib.Path(sys.argv[3]).write_text('\n'.join(rows)+'\n')
print('installed_springy_themes=48')
print('installed_snowboard_themes=160')
print('installed_gallery_total=274')
PY

mkdir -p "$MEDIA_ROOT" "$OPEN_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
find "$MEDIA_ROOT" -type d -exec chmod 0755 {} +
find "$MEDIA_ROOT" -type f -exec chmod 0644 {} +
find "$OPEN_ROOT" -maxdepth 1 -type d -name '.download-*' -exec rm -rf {} + 2>/dev/null || true

TAB="$(printf '\t')"
INDEX=0
while IFS="$TAB" read -r KIND EXPECTED_PACKAGE EXPECTED_BYTES EXPECTED_SHA DOWNLOAD_URL ARCHIVE_SUBPATH DISPLAY_NAME; do
  INDEX=$((INDEX + 1))
  CASE_DIR="$WORK/$KIND"
  DEB="$CASE_DIR/theme.deb"
  STDOUT_FILE="$CASE_DIR/package.stdout"
  STDERR_FILE="$CASE_DIR/package.stderr"
  MERGED_FILE="$CASE_DIR/package.merged"
  EXTRACTED="$CASE_DIR/extracted"
  mkdir -p "$CASE_DIR" "$EXTRACTED"
  chown -R mobile:mobile "$CASE_DIR"

  EFFECTIVE_URL="$(sudo -u mobile curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$DEB" --write-out '%{url_effective}' "$DOWNLOAD_URL")"
  printf '%s_effective_url=%s\n' "$KIND" "$EFFECTIVE_URL"
  ACTUAL_BYTES="$(wc -c < "$DEB" | tr -d ' ')"
  ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
  test "$ACTUAL_BYTES" = "$EXPECTED_BYTES"
  test "$ACTUAL_SHA" = "$EXPECTED_SHA"

  sudo -u mobile sh -c 'dpkg-deb -f "$1" Package >"$2" 2>"$3"' sh "$DEB" "$STDOUT_FILE" "$STDERR_FILE"
  CLEAN_PACKAGE="$(tr -d '\r\n' < "$STDOUT_FILE")"
  STDERR_BYTES="$(wc -c < "$STDERR_FILE" | tr -d ' ')"
  printf '%s_expected_package=%s\n' "$KIND" "$EXPECTED_PACKAGE"
  printf '%s_clean_stdout_package=%s\n' "$KIND" "$CLEAN_PACKAGE"
  printf '%s_stderr_bytes=%s\n' "$KIND" "$STDERR_BYTES"
  test "$CLEAN_PACKAGE" = "$EXPECTED_PACKAGE"

  sudo -u mobile sh -c 'dpkg-deb -f "$1" Package >"$2" 2>&1' sh "$DEB" "$MERGED_FILE"
  MERGED_VALUE="$(tr '\n' ' ' < "$MERGED_FILE" | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')"
  if [ "$MERGED_VALUE" != "$EXPECTED_PACKAGE" ]; then
    printf '%s_old_merged_capture_would_fail=true\n' "$KIND"
  else
    printf '%s_old_merged_capture_would_fail=false\n' "$KIND"
  fi

  dpkg-deb -x "$DEB" "$EXTRACTED"
  if [ -n "$ARCHIVE_SUBPATH" ]; then
    test -d "$EXTRACTED/$ARCHIVE_SUBPATH"
  else
    MEDIA_COUNT="$(find "$EXTRACTED" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
    test "$MEDIA_COUNT" -ge 1
    printf '%s_media_files=%s\n' "$KIND" "$MEDIA_COUNT"
  fi
  OWNER_UID="$(ls -dn "$DEB" | awk '{print $3}')"
  test "$OWNER_UID" = '501'
  printf '%s_package_id_verification=passed|%s|%s|owner_uid=%s\n' "$KIND" "$EXPECTED_PACKAGE" "$DISPLAY_NAME" "$OWNER_UID"
done < "$WORK/tests.tsv"
test "$INDEX" = '2'

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 6
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_6s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.7'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
printf 'gallery_label='; grep -o '[0-9]*-THEME ANIMATION GALLERY' "$ROOT_PLIST" | head -n 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi

echo 'gif2ani_357_install=success'
echo 'gif2ani_357_shared_package_id_fix=success'
echo 'gif2ani_357_springy_gameboy_advance=success'
echo 'gif2ani_357_snowboard_package=success'
echo 'gif2ani_357_gallery_total_274=success'
