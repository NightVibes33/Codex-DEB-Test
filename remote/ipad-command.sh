#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

URL='https://raw.githubusercontent.com/NightVibes33/Dark-Boot/main/release-packages/Gif2Ani-3.4.1-gallery-crash-hotfix.deb'
EXPECTED_SHA='722709acc93a489f5f7f6239338d01a3d1d3d203ba98ae9eb7b435714b747883'
DEB='/var/mobile/Library/Caches/Gif2Ani-3.4.1-gallery-crash-hotfix.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
ROOT_PLIST="$BUNDLE/Root.plist"
CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
MARKER='/var/mobile/Library/Caches/gif2ani-gallery-hotfix-test.marker'

echo '=== Install Gif2Ani gallery crash hotfix ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true

rm -f "$DEB"
curl -fL --retry 4 --retry-delay 2 --connect-timeout 20 --max-time 180 "$URL" -o "$DEB"
ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
printf 'downloaded_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$EXPECTED_SHA"
test "$(dpkg-deb -f "$DEB" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$DEB" Version)" = '3.4.1'
test "$(dpkg-deb -f "$DEB" Architecture)" = 'iphoneos-arm64'

dpkg -i "$DEB"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.4.1'
test -s "$BUNDLE/Gif2AniPrefs"
test -f "$ROOT_PLIST"

python3 - "$ROOT_PLIST" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f:
    root=plistlib.load(f)
rows=[x for x in root.get('items',[]) if isinstance(x,dict) and x.get('label')=='Browse and Preview Animations']
assert len(rows)==1, rows
row=rows[0]
assert row.get('cell')=='PSButtonCell', row
assert row.get('action')=='openAnimationGallery', row
assert 'detail' not in row, row
assert row.get('id')=='G2ThemeGallery', row
print('browse_row_cell='+row['cell'])
print('browse_row_action='+row['action'])
print('legacy_detail_removed=true')
PY

if command -v strings >/dev/null 2>&1; then
  strings "$BUNDLE/Gif2AniPrefs" | grep -Fq 'openAnimationGallery'
  strings "$BUNDLE/Gif2AniPrefs" | grep -Fq 'G2ThemeGalleryController'
  echo 'compiled_navigation_selectors=passed'
else
  echo 'compiled_navigation_selectors=strings_unavailable'
fi

rm -f "$MARKER"
touch "$MARKER"
killall -9 Preferences 2>/dev/null || true
sleep 2
if command -v uiopen >/dev/null 2>&1; then
  su mobile -c "uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true
fi
sleep 6
printf 'preferences_after_root_open='; ps -A 2>/dev/null | grep '[P]references' | head -n1 || true

if command -v uiopen >/dev/null 2>&1; then
  su mobile -c "uiopen 'prefs:root=Gif2Ani&G2ThemeGallery'" >/dev/null 2>&1 || true
fi
sleep 6
printf 'preferences_after_gallery_deeplink='; ps -A 2>/dev/null | grep '[P]references' | head -n1 || true

NEW_CRASHES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -newer "$MARKER" -print 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_preferences_crashes=%s\n' "$NEW_CRASHES"
test "$NEW_CRASHES" = '0'

echo 'gallery_crash_hotfix_install=success'
echo 'settings_launch_test=success'
echo 'browse_preview_navigation_fix=installed'
printf 'completed_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
