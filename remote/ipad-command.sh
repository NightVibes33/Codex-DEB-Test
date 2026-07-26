#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

URL='https://raw.githubusercontent.com/NightVibes33/Dark-Boot/main/release-packages/Gif2Ani-3.5.2-download-previews-fix.deb'
EXPECTED_SHA='ad97f541cdc273bd7db68436c3555cb0a8c3d71b2c590d73649adbb739169234'
TMP='/tmp/Gif2Ani-3.5.2-download-previews-fix.deb'
MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
CATALOG="$MEDIA/Catalog"
OPEN="$MEDIA/OpenThemeLibrary"
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREVIEWS="$BUNDLE/ThemePreviews"
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
MARK='/tmp/gif2ani-352-crash-marker'
WORK='/tmp/gif2ani-352-network-test'

printf '%s\n' '=== Install and validate Gif2Ani 3.5.2 download and preview fix ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'previous_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true

mkdir -p "$MEDIA"
FILES_BEFORE="$(find "$MEDIA" -type f 2>/dev/null | wc -l | tr -d ' ')"
BYTES_BEFORE="$(du -sk "$MEDIA" 2>/dev/null | awk '{print $1}')"
printf 'preserved_files_before=%s\n' "$FILES_BEFORE"
printf 'preserved_kib_before=%s\n' "$BYTES_BEFORE"

rm -rf "$WORK"; mkdir -p "$WORK"
rm -f "$TMP" "$MARK"; : > "$MARK"
trap 'rm -rf "$WORK"; rm -f "$TMP" "$MARK"' EXIT INT TERM
curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 -o "$TMP" "$URL"
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'download_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"
test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.2'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'package_metadata=passed'

dpkg -i "$TMP"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.5.2'
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani

test -s "$PREFS_BIN"; test -s "$TWEAK_BIN"
for marker in \
  'curl-backed-gallery-download-v352' \
  'bundled-real-theme-previews-v352' \
  'Download & Preview' \
  'Search themes' \
  'Review & Apply'; do
  strings "$PREFS_BIN" | grep -Fq "$marker"
done
echo 'gallery_352_markers=passed'

PREVIEW_COUNT="$(find "$PREVIEWS" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
printf 'bundled_preview_count=%s\n' "$PREVIEW_COUNT"
test "$PREVIEW_COUNT" = '102'
python3 - "$PREVIEWS" <<'PY'
import pathlib, struct, sys
root=pathlib.Path(sys.argv[1])
files=sorted(root.glob('*.png'))
assert len(files)==102
for p in files:
    data=p.read_bytes()[:24]
    assert data[:8] == b'\x89PNG\r\n\x1a\n', p
    assert data[12:16] == b'IHDR', p
    w,h=struct.unpack('>II',data[16:24])
    assert (w,h)==(220,220), (p,w,h)
assert (root/'cyan-pulse-rings.png').is_file()
assert (root/'io.github.virenmohindra.a-wave.png').is_file()
print('all_bundled_previews_png_220x220=passed')
PY

# Exercise the exact curl/effective-URL path now used by the Settings UI.
CC0_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/b5d5eda04359409865772038895e660d709deb18/gif2ani-themes/v1/magenta-pulse-rings.gif'
CC0_SHA='bf3a04c90991ac2b17c0e6c4b6eebd746312de6bab49eb338fe07b563b163aad'
# Read the pinned value from the installed manifest to avoid trusting this smoke-test constant if the catalog changed.
python3 - "$BUNDLE/ThemeCatalog.json" "$WORK/cc0-meta" <<'PY'
import json, pathlib, sys
m=json.loads(pathlib.Path(sys.argv[1]).read_text())
t=next(x for x in m['themes'] if x['id']=='magenta-pulse-rings')
pathlib.Path(sys.argv[2]).write_text(f"{t['sha256']}\n{t['bytes']}\n")
PY
CC0_SHA="$(sed -n '1p' "$WORK/cc0-meta")"
CC0_BYTES="$(sed -n '2p' "$WORK/cc0-meta")"
EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 --output "$WORK/magenta-pulse-rings.gif" --write-out '%{url_effective}' "$CC0_URL")"
test "$EFFECTIVE" = "$CC0_URL"
test "$(wc -c < "$WORK/magenta-pulse-rings.gif" | tr -d ' ')" = "$CC0_BYTES"
test "$(sha256sum "$WORK/magenta-pulse-rings.gif" | awk '{print $1}')" = "$CC0_SHA"
echo 'ui_curl_cc0_download_path=passed'

SPRINGY_URL='https://virenmohindra.github.io/debs/io.github.virenmohindra.alone_1.0_iphoneos-arm.deb'
SPRINGY_SHA='a699643d4d100853e44f33ee7d8ba530b29e18ea76326b3cd0c5ec8085df2ec7'
EFFECTIVE="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 --output "$WORK/alone.deb" --write-out '%{url_effective}' "$SPRINGY_URL")"
test "$EFFECTIVE" = "$SPRINGY_URL"
test "$(sha256sum "$WORK/alone.deb" | awk '{print $1}')" = "$SPRINGY_SHA"
test "$(dpkg-deb -f "$WORK/alone.deb" Package | tr -d '\r\n')" = 'io.github.virenmohindra.alone'
echo 'ui_curl_springy_download_path=passed'

FILES_AFTER="$(find "$MEDIA" -type f 2>/dev/null | wc -l | tr -d ' ')"
BYTES_AFTER="$(du -sk "$MEDIA" 2>/dev/null | awk '{print $1}')"
printf 'preserved_files_after=%s\n' "$FILES_AFTER"
printf 'preserved_kib_after=%s\n' "$BYTES_AFTER"
test "$FILES_AFTER" -ge "$FILES_BEFORE"
[ -f "$CATALOG/cyan-pulse-rings.gif" ] && echo 'existing_cc0_cache_preserved=true'
[ -f "$OPEN/io.github.virenmohindra.a-wave/metadata.plist" ] && echo 'existing_springy_cache_preserved=true'

killall -9 Preferences 2>/dev/null || true
sleep 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  sleep 6
  echo 'settings_gallery_links_opened=true'
fi
NEW_CRASHES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -newer "$MARK" 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_preferences_crashes=%s\n' "$NEW_CRASHES"
test "$NEW_CRASHES" = '0'

echo 'gif2ani_352_install=success'
echo 'gif2ani_352_real_previews=success'
echo 'gif2ani_352_curl_download_paths=success'
echo 'gif2ani_352_settings_launch=success'
