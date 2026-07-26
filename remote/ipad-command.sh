#!/bin/sh
# bridge-retrigger=2026-07-26T10:47:00-05:00
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

RELEASE_COMMIT='fa5f035abf2e419c3075f439f9f853daa2ba56b1'
URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.5-exact-pack-names.deb"
EXPECTED_SHA='cf394b66554b8a8085dfc1d60789031ea38cc18d74df39dab66ab6ce9214e74b'
TMP='/tmp/Gif2Ani-3.5.5-exact-pack-names.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
ROOT_PLIST="$BUNDLE/Root.plist"
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
PREVIEWS="$BUNDLE/ThemePreviews"
OPEN_CATALOG="$BUNDLE/OpenThemeCatalog.json"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
SPRINGY_CACHE="$MEDIA_ROOT/OpenThemeLibrary"
WORK='/tmp/gif2ani-355-all-pack-audit'

printf '%s\n' '=== Install Gif2Ani 3.5.5 and audit all 48 exact pack names on iPad ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

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
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.5'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.5'

test -s "$PREFS_BIN"
test -s "$TWEAK_BIN"
test -s "$OPEN_CATALOG"
test -s "$ROOT_PLIST"
grep -Fq 'GIF2ANI 3.5.5' "$ROOT_PLIST"
! grep -Fq 'GIF2ANI 3.4.1' "$ROOT_PLIST"
! grep -Fq 'GIF2ANI 3.5.4' "$ROOT_PLIST"
strings "$PREFS_BIN" | grep -Fq 'raw.githubusercontent.com/VirenMohindra/CydiaRepo/'
echo 'installed_version_and_code=passed'

python3 - "$PREVIEWS" "$OPEN_CATALOG" "$WORK/packs.tsv" <<'PY'
import json, pathlib, re, struct, sys
previews = pathlib.Path(sys.argv[1])
catalog_path = pathlib.Path(sys.argv[2])
out = pathlib.Path(sys.argv[3])
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
assert catalog.get('namesDerivedFromDEBMetadata') is True
assert catalog.get('immutableCatalogVerifiedAtUTC', '').endswith('Z')
assert len({x['identifier'] for x in themes}) == 48
rows = []
for index, pack in enumerate(themes, 1):
    assert pack['identifier'] == pack['package']
    assert re.fullmatch(r'[0-9a-f]{40}', pack['sourceCommit'])
    assert re.fullmatch(r'[0-9a-f]{64}', pack['sha256'])
    assert isinstance(pack['name'], str) and pack['name'].strip()
    assert isinstance(pack['sourcePackageName'], str) and pack['sourcePackageName'].strip()
    expected_url = f"https://raw.githubusercontent.com/VirenMohindra/CydiaRepo/{pack['sourceCommit']}/{pack['filename'][2:]}"
    assert pack['downloadURL'] == expected_url
    assert int(pack['immutableVerifiedMediaFiles']) >= 2
    assert (previews / f"{pack['identifier']}.png").is_file()
    fields = [str(index), pack['identifier'], pack['package'], pack['name'].strip(), pack['sourcePackageName'].strip(), str(pack['bytes']), pack['sha256'], pack['downloadURL']]
    assert all('\t' not in value and '\n' not in value for value in fields)
    rows.append('\t'.join(fields))
stranger = next(x for x in themes if x['identifier'] == 'io.github.virenmohindra.stranger-things')
assert stranger['name'] == 'Stranger Things (DankerThings)'
out.write_text('\n'.join(rows) + '\n')
print('bundled_preview_count=102')
print('all_bundled_previews_png_220x220=passed')
print('immutable_catalog_count=48')
print('catalog_preview_identity_mapping=passed')
print('stranger_things_dankerthings_name=passed')
PY

rm -rf "$SPRINGY_CACHE"
mkdir -p "$SPRINGY_CACHE"
echo 'stale_springy_cache_cleared=true'

PASSED=0
TAB="$(printf '\t')"
while IFS="$TAB" read -r INDEX IDENT PACKAGE DISPLAY_NAME SOURCE_NAME EXPECTED_BYTES EXPECTED_PACK_SHA PACK_URL; do
  PACK_DEB="$WORK/pack.deb"
  rm -f "$PACK_DEB"
  PACK_EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$PACK_DEB" --write-out '%{url_effective}' "$PACK_URL")"
  test "$PACK_EFFECTIVE" = "$PACK_URL"
  ACTUAL_BYTES="$(wc -c < "$PACK_DEB" | tr -d ' ')"
  ACTUAL_PACK_SHA="$(sha256sum "$PACK_DEB" | awk '{print $1}')"
  ACTUAL_PACKAGE="$(dpkg-deb -f "$PACK_DEB" Package | tr -d '\r\n')"
  ACTUAL_SOURCE_NAME="$(dpkg-deb -f "$PACK_DEB" Name | tr -d '\r\n')"
  ACTUAL_DISPLAY_NAME="$(python3 - "$ACTUAL_SOURCE_NAME" <<'PY'
import re, sys
value = re.sub(r'\s*-\s*Springy BootLogo\b', '', sys.argv[1], flags=re.I)
value = re.sub(r'\s+', ' ', value).strip()
print(value)
PY
)"
  test "$ACTUAL_BYTES" = "$EXPECTED_BYTES"
  test "$ACTUAL_PACK_SHA" = "$EXPECTED_PACK_SHA"
  test "$ACTUAL_PACKAGE" = "$PACKAGE"
  test "$ACTUAL_SOURCE_NAME" = "$SOURCE_NAME"
  test "$ACTUAL_DISPLAY_NAME" = "$DISPLAY_NAME"
  PASSED=$((PASSED + 1))
  printf 'pack_%02d=passed|%s|%s\n' "$INDEX" "$IDENT" "$DISPLAY_NAME"
  rm -f "$PACK_DEB"
done < "$WORK/packs.tsv"

test "$PASSED" = '48'
printf 'on_device_pack_downloads_passed=%s\n' "$PASSED"
echo 'all_48_exact_names_match_deb_metadata=passed'

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 5
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_5s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.5'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1

if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  echo 'gif2ani_settings_reopened=true'
fi

printf 'tweak_binary_sha256='; sha256sum "$TWEAK_BIN" | awk '{print $1}'
printf 'prefs_binary_sha256='; sha256sum "$PREFS_BIN" | awk '{print $1}'
echo 'gif2ani_355_install=success'
echo 'gif2ani_355_all_48_downloads=success'
echo 'gif2ani_355_exact_names_and_previews=success'
