#!/bin/sh
# bridge-retrigger=2026-07-26T10:25:00-05:00
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

RELEASE_COMMIT='5bc5a98d688a71d5f48d32d554db1d965fcf3268'
URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.3-immutable-springy-fix.deb"
EXPECTED_SHA='ea4e5ac0c565587e9e9a36084a7a788128c2167cb1ec6b880a1194f974297a3d'
TMP='/tmp/Gif2Ani-3.5.3-immutable-springy-fix.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
PREVIEWS="$BUNDLE/ThemePreviews"
OPEN_CATALOG="$BUNDLE/OpenThemeCatalog.json"
WORK='/tmp/gif2ani-353-springy-test'

printf '%s\n' '=== Install and physical-test Gif2Ani 3.5.3 ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

rm -rf "$WORK"
mkdir -p "$WORK"
rm -f "$TMP"
trap 'rm -rf "$WORK"; rm -f "$TMP"' EXIT INT TERM

EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 240 --output "$TMP" --write-out '%{url_effective}' "$URL")"
printf 'release_effective_url=%s\n' "$EFFECTIVE"
test "$EFFECTIVE" = "$URL"
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'release_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"
test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.3'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.3'

test -s "$PREFS_BIN"
test -s "$TWEAK_BIN"
test -s "$OPEN_CATALOG"
test "$(find "$PREVIEWS" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')" = '102'
strings "$PREFS_BIN" | grep -Fq 'raw.githubusercontent.com/VirenMohindra/CydiaRepo/'
echo 'installed_bundle_and_previews=passed'

python3 - "$OPEN_CATALOG" "$WORK/springy-meta" <<'PY'
import json, pathlib, re, sys
catalog = json.loads(pathlib.Path(sys.argv[1]).read_text())
pack = next(x for x in catalog['themes'] if x['identifier'] == 'io.github.virenmohindra.alone')
commit = pack['sourceCommit'].lower()
filename = pack['filename']
assert re.fullmatch(r'[0-9a-f]{40}', commit)
assert filename.startswith('./debs/') and filename.endswith('.deb')
assert '..' not in filename and '\\' not in filename
url = f"https://raw.githubusercontent.com/VirenMohindra/CydiaRepo/{commit}/{filename[2:]}"
pathlib.Path(sys.argv[2]).write_text('\n'.join([
    pack['package'], commit, filename, pack['sha256'].lower(), str(pack['bytes']), url
]) + '\n')
PY
SPRINGY_PACKAGE="$(sed -n '1p' "$WORK/springy-meta")"
SPRINGY_COMMIT="$(sed -n '2p' "$WORK/springy-meta")"
SPRINGY_FILENAME="$(sed -n '3p' "$WORK/springy-meta")"
SPRINGY_SHA="$(sed -n '4p' "$WORK/springy-meta")"
SPRINGY_BYTES="$(sed -n '5p' "$WORK/springy-meta")"
SPRINGY_URL="$(sed -n '6p' "$WORK/springy-meta")"
printf 'springy_package=%s\n' "$SPRINGY_PACKAGE"
printf 'springy_source_commit=%s\n' "$SPRINGY_COMMIT"
printf 'springy_filename=%s\n' "$SPRINGY_FILENAME"
printf 'springy_pinned_url=%s\n' "$SPRINGY_URL"

SPRINGY_DEB="$WORK/alone.deb"
SPRINGY_EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 240 --output "$SPRINGY_DEB" --write-out '%{url_effective}' "$SPRINGY_URL")"
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
test "$SPRINGY_MEDIA_COUNT" -ge 2
echo 'immutable_springy_physical_download=passed'

killall -9 Preferences 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 12
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_12s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.3'

if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'settings_gallery_opened=true'
fi

printf 'tweak_binary_sha256='; sha256sum "$TWEAK_BIN" | awk '{print $1}'
printf 'prefs_binary_sha256='; sha256sum "$PREFS_BIN" | awk '{print $1}'
echo 'gif2ani_353_install=success'
echo 'gif2ani_353_immutable_springy_download=success'
echo 'gif2ani_353_real_previews=success'
