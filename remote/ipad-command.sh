#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

RELEASE_COMMIT='e0017ea96de60af7927c0acfea557ee070115fa2'
URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.4-verified-immutable-springy.deb"
EXPECTED_SHA='3dbfd641411d98cdb766d059a01da55c2c03cfe8e7b70fd7551e942ba3492bb2'
TMP='/tmp/Gif2Ani-3.5.4-verified-immutable-springy.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
ROOT_PLIST="$BUNDLE/Root.plist"
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
PREVIEWS="$BUNDLE/ThemePreviews"
OPEN_CATALOG="$BUNDLE/OpenThemeCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
WORK='/tmp/gif2ani-354-final-test'

printf '%s\n' '=== Install and physical-test final Gif2Ani 3.5.4 ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent
printf 'user_media_files_before='; find "$MEDIA_ROOT" -type f 2>/dev/null | wc -l | tr -d ' '

rm -rf "$WORK"
mkdir -p "$WORK"
rm -f "$TMP"
trap 'rm -rf "$WORK"; rm -f "$TMP"' EXIT INT TERM

EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$TMP" --write-out '%{url_effective}' "$URL")"
printf 'release_effective_url=%s\n' "$EFFECTIVE"
test "$EFFECTIVE" = "$URL"
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'release_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"
test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.4'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.4'

test -s "$PREFS_BIN"
test -s "$TWEAK_BIN"
test -s "$OPEN_CATALOG"
test -s "$ROOT_PLIST"
grep -Fq 'GIF2ANI 3.5.4' "$ROOT_PLIST"
if grep -Fq 'GIF2ANI 3.5.3' "$ROOT_PLIST"; then
  echo 'stale_visible_version=true'
  exit 1
fi
strings "$PREFS_BIN" | grep -Fq 'raw.githubusercontent.com/VirenMohindra/CydiaRepo/'
echo 'version_label_and_immutable_code=passed'

python3 - "$PREVIEWS" "$OPEN_CATALOG" "$WORK/springy-meta" <<'PY'
import json, pathlib, plistlib, re, struct, sys
previews = pathlib.Path(sys.argv[1])
catalog_path = pathlib.Path(sys.argv[2])
meta_path = pathlib.Path(sys.argv[3])
files = sorted(previews.glob('*.png'))
assert len(files) == 102, len(files)
for path in files:
    data = path.read_bytes()[:24]
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    assert data[12:16] == b'IHDR', path
    assert struct.unpack('>II', data[16:24]) == (220, 220), path
catalog = json.loads(catalog_path.read_text())
themes = catalog['themes']
assert catalog['count'] == len(themes) == 48
assert catalog.get('immutableCatalogVerifiedAtUTC', '').endswith('Z')
assert len({x['identifier'] for x in themes}) == 48
for pack in themes:
    assert pack['identifier'] == pack['package']
    assert re.fullmatch(r'[0-9a-f]{40}', pack['sourceCommit'])
    assert re.fullmatch(r'[0-9a-f]{64}', pack['sha256'])
    expected_url = f"https://raw.githubusercontent.com/VirenMohindra/CydiaRepo/{pack['sourceCommit']}/{pack['filename'][2:]}"
    assert pack['downloadURL'] == expected_url
    assert int(pack['immutableVerifiedMediaFiles']) >= 2
pack = next(x for x in themes if x['identifier'] == 'io.github.virenmohindra.alone')
meta_path.write_text('\n'.join([
    pack['package'], pack['sourceCommit'], pack['filename'], pack['sha256'],
    str(pack['bytes']), pack['downloadURL'], str(pack['immutableVerifiedMediaFiles'])
]) + '\n')
print('bundled_preview_count=102')
print('all_bundled_previews_png_220x220=passed')
print('immutable_catalog_count=48')
print('all_immutable_catalog_records=passed')
PY

SPRINGY_PACKAGE="$(sed -n '1p' "$WORK/springy-meta")"
SPRINGY_COMMIT="$(sed -n '2p' "$WORK/springy-meta")"
SPRINGY_FILENAME="$(sed -n '3p' "$WORK/springy-meta")"
SPRINGY_SHA="$(sed -n '4p' "$WORK/springy-meta")"
SPRINGY_BYTES="$(sed -n '5p' "$WORK/springy-meta")"
SPRINGY_URL="$(sed -n '6p' "$WORK/springy-meta")"
SPRINGY_EXPECTED_MEDIA="$(sed -n '7p' "$WORK/springy-meta")"
printf 'springy_package=%s\n' "$SPRINGY_PACKAGE"
printf 'springy_source_commit=%s\n' "$SPRINGY_COMMIT"
printf 'springy_filename=%s\n' "$SPRINGY_FILENAME"
printf 'springy_url=%s\n' "$SPRINGY_URL"

SPRINGY_DEB="$WORK/alone.deb"
SPRINGY_EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$SPRINGY_DEB" --write-out '%{url_effective}' "$SPRINGY_URL")"
printf 'springy_effective_url=%s\n' "$SPRINGY_EFFECTIVE"
test "$SPRINGY_EFFECTIVE" = "$SPRINGY_URL"
ACTUAL_BYTES="$(wc -c < "$SPRINGY_DEB" | tr -d ' ')"
ACTUAL_SPRINGY_SHA="$(sha256sum "$SPRINGY_DEB" | awk '{print $1}')"
printf 'springy_actual_bytes=%s\n' "$ACTUAL_BYTES"
printf 'springy_expected_bytes=%s\n' "$SPRINGY_BYTES"
printf 'springy_actual_sha256=%s\n' "$ACTUAL_SPRINGY_SHA"
printf 'springy_expected_sha256=%s\n' "$SPRINGY_SHA"
test "$ACTUAL_BYTES" = "$SPRINGY_BYTES"
test "$ACTUAL_SPRINGY_SHA" = "$SPRINGY_SHA"
test "$(dpkg-deb -f "$SPRINGY_DEB" Package | tr -d '\r\n')" = "$SPRINGY_PACKAGE"
mkdir -p "$WORK/extracted"
dpkg-deb -x "$SPRINGY_DEB" "$WORK/extracted"
SPRINGY_MEDIA_COUNT="$(find "$WORK/extracted" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
printf 'springy_extracted_media_count=%s\n' "$SPRINGY_MEDIA_COUNT"
printf 'springy_manifest_media_count=%s\n' "$SPRINGY_EXPECTED_MEDIA"
test "$SPRINGY_MEDIA_COUNT" = "$SPRINGY_EXPECTED_MEDIA"
echo 'immutable_springy_physical_download=passed'

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 5
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_5s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.4'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
printf 'user_media_files_after='; find "$MEDIA_ROOT" -type f 2>/dev/null | wc -l | tr -d ' '

if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  echo 'gif2ani_settings_reopened=true'
fi

printf 'tweak_binary_sha256='; sha256sum "$TWEAK_BIN" | awk '{print $1}'
printf 'prefs_binary_sha256='; sha256sum "$PREFS_BIN" | awk '{print $1}'
echo 'gif2ani_354_install=success'
echo 'gif2ani_354_48_download_records=success'
echo 'gif2ani_354_102_real_previews=success'
echo 'gif2ani_354_physical_springy_download=success'
