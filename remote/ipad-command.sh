#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

URL='https://raw.githubusercontent.com/NightVibes33/Dark-Boot/main/release-packages/Gif2Ani-3.5.1-gallery-polish.deb'
EXPECTED_SHA='f57a43519841453ec81251a117673e12dacbd8440c1ebdc6844091c6cb7b5d0f'
TMP='/tmp/Gif2Ani-3.5.1-gallery-polish.deb'
MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
CATALOG="$MEDIA/Catalog"
OPEN="$MEDIA/OpenThemeLibrary"
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
MARK='/tmp/gif2ani-351-crash-marker'

printf '%s\n' '=== Install and validate Gif2Ani 3.5.1 gallery polish ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'previous_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true

mkdir -p "$MEDIA"
FILES_BEFORE="$(find "$MEDIA" -type f 2>/dev/null | wc -l | tr -d ' ')"
BYTES_BEFORE="$(du -sk "$MEDIA" 2>/dev/null | awk '{print $1}')"
CC0_BEFORE='missing'
[ -f "$CATALOG/cyan-pulse-rings.gif" ] && CC0_BEFORE="$(sha256sum "$CATALOG/cyan-pulse-rings.gif" | awk '{print $1}')"
SPRINGY_BEFORE='missing'
[ -f "$OPEN/io.github.virenmohindra.a-wave/metadata.plist" ] && SPRINGY_BEFORE='present'
printf 'preserved_files_before=%s\n' "$FILES_BEFORE"
printf 'preserved_kib_before=%s\n' "$BYTES_BEFORE"
printf 'cc0_before=%s\n' "$CC0_BEFORE"
printf 'springy_before=%s\n' "$SPRINGY_BEFORE"

rm -f "$TMP" "$MARK"; : > "$MARK"
trap 'rm -f "$TMP" "$MARK"' EXIT INT TERM
if command -v curl >/dev/null 2>&1; then
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 120 -o "$TMP" "$URL"
else
  wget -q -O "$TMP" "$URL"
fi
ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'download_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"
test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.1'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'package_metadata=passed'

dpkg -i "$TMP"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.5.1'
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani

test -s "$PREFS_BIN"; test -s "$TWEAK_BIN"
for marker in \
  'bounded-ephemeral-download-all' \
  'Download All 54 CC0 Themes' \
  'Search themes' \
  'Apply Without Respring' \
  'Emergency Disable (No Respring)'; do
  strings "$PREFS_BIN" | grep -Fq "$marker"
done
echo 'gallery_351_markers=passed'
for marker in 'memory-pressure-frames-released' 'custom-animation-finished-frames-released' 'ImageIO-bounded-thumbnail-serial-queue'; do
  strings "$TWEAK_BIN" | grep -Fq "$marker"
done
echo 'backboard_markers_preserved=passed'

FILES_AFTER="$(find "$MEDIA" -type f 2>/dev/null | wc -l | tr -d ' ')"
BYTES_AFTER="$(du -sk "$MEDIA" 2>/dev/null | awk '{print $1}')"
printf 'preserved_files_after=%s\n' "$FILES_AFTER"
printf 'preserved_kib_after=%s\n' "$BYTES_AFTER"
test "$FILES_AFTER" -ge "$FILES_BEFORE"

test -f "$CATALOG/cyan-pulse-rings.gif"
test "$(sha256sum "$CATALOG/cyan-pulse-rings.gif" | awk '{print $1}')" = '1975aa569fb5ee0002856a7cff3b60bbcde04126514386fbd52b89d9f5349a46'
echo 'cc0_cache_preserved=true'
test -f "$OPEN/io.github.virenmohindra.a-wave/metadata.plist"
python3 - "$OPEN/io.github.virenmohindra.a-wave/metadata.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1],'rb') as f: m=plistlib.load(f)
assert m.get('package') == 'io.github.virenmohindra.a-wave'
assert m.get('sha256') == '853d01e5a41092561d47dc6ccfc87b9e547dd926b7ba1daa9980fe148e276279'
assert m.get('kind') in ('gif','frames')
print('springy_cache_preserved=true')
PY

killall -9 Preferences 2>/dev/null || true
sleep 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  sleep 5
  echo 'settings_gallery_links_opened=true'
fi
NEW_CRASHES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -newer "$MARK" 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_preferences_crashes=%s\n' "$NEW_CRASHES"
test "$NEW_CRASHES" = '0'

echo 'gif2ani_351_install=success'
echo 'gif2ani_351_upgrade_preservation=success'
echo 'gif2ani_351_settings_launch=success'
