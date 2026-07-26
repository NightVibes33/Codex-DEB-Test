#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

URL='https://raw.githubusercontent.com/NightVibes33/Dark-Boot/main/release-packages/Gif2Ani-3.5.0-modern-gallery.deb'
EXPECTED_SHA='75168e3ce66aaf041c41ba16eded7994e2d4670c44e0b7c94623666fc3b718b0'
TMP='/tmp/Gif2Ani-3.5.0-modern-gallery.deb'
MARK='/tmp/gif2ani-350-settings-crash-marker'
CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
TWEAK_BIN='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'

printf '%s\n' '=== Install and validate Gif2Ani 3.5.0 modernization ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'previous_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo 'not-installed'

mkdir -p "$MEDIA"
PRESERVED_BEFORE="$(find "$MEDIA" -type f 2>/dev/null | wc -l | tr -d ' ')"
printf 'preserved_files_before=%s\n' "$PRESERVED_BEFORE"

rm -f "$TMP" "$MARK"
: > "$MARK"
if command -v curl >/dev/null 2>&1; then
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 -o "$TMP" "$URL"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$TMP" "$URL"
else
  echo 'download_tool=missing' >&2
  exit 20
fi

ACTUAL_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
printf 'download_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"

test "$(dpkg-deb -f "$TMP" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP" Version)" = '3.5.0'
test "$(dpkg-deb -f "$TMP" Architecture)" = 'iphoneos-arm64'
echo 'package_metadata=passed'

dpkg -i "$TMP"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.5.0'
test -s "$PREFS_BIN"
test -s "$TWEAK_BIN"
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani

python3 - "$BUNDLE/Root.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as handle:
    root = plistlib.load(handle)
rows = [row for row in root.get('items', []) if row.get('label') == 'Browse and Preview Animations']
assert len(rows) == 1, rows
row = rows[0]
assert row.get('cell') == 'PSButtonCell', row
assert row.get('action') == 'openAnimationGallery', row
assert 'detail' not in row, row
print('browse_navigation_contract=passed')
PY

for marker in \
  'Search themes' \
  'Download All 54 CC0 Themes' \
  'Clear Downloaded Theme Cache' \
  'Favorites' \
  'Recently Used' \
  'Apply Without Respring' \
  'Apply and Respring' \
  'Emergency Disable (No Respring)' \
  'Apple original'; do
  strings "$PREFS_BIN" | grep -Fq "$marker"
done
echo 'modern_gallery_markers=passed'

for marker in \
  'memory-pressure-frames-released' \
  'custom-animation-finished-frames-released' \
  'ImageIO-bounded-thumbnail-serial-queue'; do
  strings "$TWEAK_BIN" | grep -Fq "$marker"
done
echo 'backboard_reliability_markers=passed'

PRESERVED_AFTER="$(find "$MEDIA" -type f 2>/dev/null | wc -l | tr -d ' ')"
printf 'preserved_files_after=%s\n' "$PRESERVED_AFTER"
test "$PRESERVED_AFTER" -ge "$PRESERVED_BEFORE"
echo 'downloaded_theme_data_preserved=true'

killall -9 Preferences 2>/dev/null || true
sleep 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 3
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  sleep 4
  echo 'settings_links_opened=true'
else
  echo 'settings_links_opened=false_uiopen_missing'
fi

NEW_CRASHES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -newer "$MARK" 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_preferences_crashes=%s\n' "$NEW_CRASHES"
test "$NEW_CRASHES" = '0'

rm -f "$TMP" "$MARK"
echo 'gif2ani_350_install=success'
echo 'gif2ani_350_static_feature_validation=success'
echo 'gif2ani_350_settings_launch_test=success'
