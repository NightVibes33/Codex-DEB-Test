#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

RELEASE_COMMIT='6017cd4bbfbbe28821fb9657c2823d3ad8a475a5'
RELEASE_URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.6-verified-snowboard-library.deb"
RELEASE_SHA='b3de14935aea124f665803bfaa9140c0f81021e3f15add6e324ab504c1c44c16'
TMP='/tmp/Gif2Ani-3.5.6-verified-snowboard-library.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
ROOT_PLIST="$BUNDLE/Root.plist"
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
OPEN_ROOT="$MEDIA_ROOT/OpenThemeLibrary"
REMOTE_ROOT="$MEDIA_ROOT/RemoteThemes"
PACKS_ROOT="$MEDIA_ROOT/Packs"
ROLLBACK_ROOT="$MEDIA_ROOT/Rollbacks"
TEST_ROOT="$MEDIA_ROOT/SnowBoardDownloadTest"
WORK='/tmp/gif2ani-356-ipad-verify'

printf '%s\n' '=== Install Gif2Ani 3.5.6 and audit all verified SnowBoard packages on iPad ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

rm -rf "$WORK" "$TEST_ROOT"
mkdir -p "$WORK"
rm -f "$TMP"
trap 'rm -rf "$WORK" "$TEST_ROOT"; rm -f "$TMP"' EXIT INT TERM

EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$TMP" --write-out '%{url_effective}' "$RELEASE_URL")"
printf 'release_effective_url=%s\n' "$EFFECTIVE"
test "$EFFECTIVE" = "$RELEASE_URL"
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'release_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$RELEASE_SHA"
test "$(dpkg-deb -f "$TMP" Package | tr -d '\r\n')" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version | tr -d '\r\n')" = '3.5.6'
test "$(dpkg-deb -f "$TMP" Architecture | tr -d '\r\n')" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.6'

test -s "$PREFS_BIN"
test -s "$TWEAK_BIN"
test -s "$ROOT_PLIST"
test -s "$SPRINGY_CATALOG"
test -s "$SNOWBOARD_CATALOG"
grep -Fq 'GIF2ANI 3.5.6' "$ROOT_PLIST"
! grep -Fq 'GIF2ANI 3.5.5' "$ROOT_PLIST"
! strings "$PREFS_BIN" | grep -Fq 'Import Pack File'
strings "$PREFS_BIN" | grep -Fq 'verified-snowboard-respring'
strings "$PREFS_BIN" | grep -Fq 'The verified SnowBoard subtheme was not present'
echo 'installed_version_code_and_legacy_ui=passed'

python3 - "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" "$WORK/packages.tsv" <<'PY'
import json, pathlib, re, sys
springy=json.loads(pathlib.Path(sys.argv[1]).read_text())
snowboard=json.loads(pathlib.Path(sys.argv[2]).read_text())
themes=snowboard['themes']
assert springy['count']==len(springy['themes'])==48
assert snowboard['catalogType']=='verified-snowboard-respring'
assert snowboard['packageCount']==7
assert snowboard['count']==len(themes)==160
assert len({x['identifier'] for x in themes})==160
assert len({x['package'] for x in themes})==7
for theme in themes:
    assert theme['identifier'].startswith('snowboard.')
    assert re.fullmatch(r'[0-9a-f]{64}',theme['sha256'])
    assert theme['downloadURL'].startswith('https://')
    assert theme['effectiveURL'].startswith('https://')
    assert theme['archiveSubpath'].lower().endswith('.theme')
    assert not theme['archiveSubpath'].startswith('/')
    assert '..' not in pathlib.PurePosixPath(theme['archiveSubpath']).parts
    assert int(theme['mediaFiles'])>=1
packages={}
for theme in themes:
    existing=packages.setdefault(theme['package'],theme)
    for key in ('bytes','sha256','downloadURL','effectiveURL','version','architecture'):
        assert existing[key]==theme[key]
rows=[]
for theme in sorted(packages.values(),key=lambda x:x['package']):
    fields=[theme['package'],str(theme['bytes']),theme['sha256'],theme['downloadURL'],theme['effectiveURL'],theme['version'],theme['architecture']]
    assert all('\t' not in value and '\n' not in value for value in fields)
    rows.append('\t'.join(fields))
pathlib.Path(sys.argv[3]).write_text('\n'.join(rows)+'\n')
print('installed_springy_themes=48')
print('installed_snowboard_packages=7')
print('installed_snowboard_themes=160')
print('installed_source_backed_themes=208')
PY

mkdir -p "$OPEN_ROOT" "$REMOTE_ROOT" "$PACKS_ROOT" "$ROLLBACK_ROOT" "$TEST_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
find "$MEDIA_ROOT" -type d -exec chmod 0755 {} +
find "$MEDIA_ROOT" -type f -exec chmod 0644 {} +

WRITE_TEST="$OPEN_ROOT/.gif2ani-mobile-write-test"
rm -f "$WRITE_TEST"
if command -v sudo >/dev/null 2>&1; then
  sudo -u mobile sh -c "printf mobile-write-ok > '$WRITE_TEST'"
else
  su mobile -c "printf mobile-write-ok > '$WRITE_TEST'"
fi
test "$(cat "$WRITE_TEST")" = 'mobile-write-ok'
WRITE_UID="$(ls -dn "$WRITE_TEST" | awk '{print $3}')"
printf 'mobile_cache_write_uid=%s\n' "$WRITE_UID"
test "$WRITE_UID" = '501'
rm -f "$WRITE_TEST"
echo 'settings_download_cache_permission=passed'

TAB="$(printf '\t')"
INDEX=0
TOTAL_THEME_PATHS=0
while IFS="$TAB" read -r PACKAGE EXPECTED_BYTES EXPECTED_SHA DOWNLOAD_URL EXPECTED_EFFECTIVE EXPECTED_VERSION EXPECTED_ARCH; do
  INDEX=$((INDEX + 1))
  PACKAGE_DIR="$TEST_ROOT/$PACKAGE"
  DEB="$PACKAGE_DIR/package.deb"
  EXTRACTED="$WORK/extracted-$INDEX"
  mkdir -p "$PACKAGE_DIR"
  chown mobile:mobile "$PACKAGE_DIR"
  if command -v sudo >/dev/null 2>&1; then
    EFFECTIVE_URL="$(sudo -u mobile curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$DEB" --write-out '%{url_effective}' "$DOWNLOAD_URL")"
  else
    EFFECTIVE_URL="$(su mobile -c "curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output '$DEB' --write-out '%{url_effective}' '$DOWNLOAD_URL'")"
  fi
  printf 'snowboard_package_%s_effective_url=%s\n' "$INDEX" "$EFFECTIVE_URL"
  test "$EFFECTIVE_URL" = "$EXPECTED_EFFECTIVE"
  ACTUAL_BYTES="$(wc -c < "$DEB" | tr -d ' ')"
  ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
  ACTUAL_PACKAGE="$(dpkg-deb -f "$DEB" Package | tr -d '\r\n')"
  ACTUAL_VERSION="$(dpkg-deb -f "$DEB" Version | tr -d '\r\n')"
  ACTUAL_ARCH="$(dpkg-deb -f "$DEB" Architecture | tr -d '\r\n')"
  OWNER_UID="$(ls -dn "$DEB" | awk '{print $3}')"
  test "$ACTUAL_BYTES" = "$EXPECTED_BYTES"
  test "$ACTUAL_SHA" = "$EXPECTED_SHA"
  test "$ACTUAL_PACKAGE" = "$PACKAGE"
  test "$ACTUAL_VERSION" = "$EXPECTED_VERSION"
  test "$ACTUAL_ARCH" = "$EXPECTED_ARCH"
  test "$OWNER_UID" = '501'
  mkdir -p "$EXTRACTED"
  dpkg-deb -x "$DEB" "$EXTRACTED"
  PACKAGE_THEME_COUNT="$(python3 - "$SNOWBOARD_CATALOG" "$PACKAGE" "$EXTRACTED" <<'PY'
import json,pathlib,sys
catalog=json.loads(pathlib.Path(sys.argv[1]).read_text())
package=sys.argv[2]
root=pathlib.Path(sys.argv[3])
media_ext={'.png','.jpg','.jpeg','.gif','.webp'}
matching=[x for x in catalog['themes'] if x['package']==package]
assert matching
for theme in matching:
    relative=pathlib.PurePosixPath(theme['archiveSubpath'])
    assert not relative.is_absolute() and '..' not in relative.parts
    directory=root.joinpath(*relative.parts)
    assert directory.is_dir(),(theme['name'],str(directory))
    media=[p for p in directory.rglob('*') if p.is_file() and p.suffix.lower() in media_ext]
    assert len(media)==int(theme['mediaFiles']),(theme['name'],len(media),theme['mediaFiles'])
    assert all(p.stat().st_size>0 for p in media)
print(len(matching))
PY
)"
  TOTAL_THEME_PATHS=$((TOTAL_THEME_PATHS + PACKAGE_THEME_COUNT))
  printf 'snowboard_package_%s=passed|%s|themes=%s|bytes=%s|sha256=%s|owner_uid=%s\n' "$INDEX" "$PACKAGE" "$PACKAGE_THEME_COUNT" "$ACTUAL_BYTES" "$ACTUAL_SHA" "$OWNER_UID"
  rm -rf "$PACKAGE_DIR" "$EXTRACTED"
done < "$WORK/packages.tsv"

test "$INDEX" = '7'
test "$TOTAL_THEME_PATHS" = '160'
printf 'physical_snowboard_packages_passed=%s\n' "$INDEX"
printf 'physical_snowboard_theme_paths_passed=%s\n' "$TOTAL_THEME_PATHS"

rm -rf "$TEST_ROOT"
killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 8
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_8s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.6'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi

printf 'tweak_binary_sha256='; sha256sum "$TWEAK_BIN" | awk '{print $1}'
printf 'prefs_binary_sha256='; sha256sum "$PREFS_BIN" | awk '{print $1}'
echo 'gif2ani_356_install=success'
echo 'gif2ani_356_snowboard_catalog=success'
echo 'gif2ani_356_mobile_download_permissions=success'
echo 'gif2ani_356_all_7_snowboard_packages=success'
echo 'gif2ani_356_all_160_snowboard_themes=success'
