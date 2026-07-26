#!/bin/sh
set -eu
ROOTLESS_PATH='/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin'
export PATH="$ROOTLESS_PATH"
export HOME=/var/mobile
export TMPDIR=/tmp
export LC_ALL=C

RELEASE_COMMIT='38c32c781735875dcf154b09c9531dd7427bf7a8'
RELEASE_URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.5.9-archive-animated-previews.deb"
RELEASE_SHA='fa8b3c766684b5d6e22056611590e24b695175f020a845180092c45fa951e583'
TMP_DEB='/tmp/Gif2Ani-3.5.9-archive-animated-previews.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
ROOT_PLIST="$BUNDLE/Root.plist"
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
PREVIEW_MANIFEST="$BUNDLE/ThemePreviewAnimations.json"
PREVIEW_ROOT="$BUNDLE/ThemePreviewAnimations"
MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
OPEN_ROOT="$MEDIA_ROOT/OpenThemeLibrary"
DIAGNOSTIC="$MEDIA_ROOT/LastPackageVerification.plist"
WORK='/tmp/gif2ani-359-device-audit'

printf '%s\n' '=== Install Gif2Ani 3.5.9 and verify real Settings download runtime ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'version_before='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

rm -rf "$WORK"
mkdir -p "$WORK"
rm -f "$TMP_DEB"
trap 'rm -rf "$WORK"; rm -f "$TMP_DEB"' EXIT INT TERM

EFFECTIVE_URL="$(curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$TMP_DEB" --write-out '%{url_effective}' "$RELEASE_URL")"
printf 'release_effective_url=%s\n' "$EFFECTIVE_URL"
test "$EFFECTIVE_URL" = "$RELEASE_URL"
ACTUAL_RELEASE_SHA="$(sha256sum "$TMP_DEB" | awk '{print $1}')"
printf 'release_sha256=%s\n' "$ACTUAL_RELEASE_SHA"
test "$ACTUAL_RELEASE_SHA" = "$RELEASE_SHA"
test "$(dpkg-deb -f "$TMP_DEB" Package | tr -d '\r\n')" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP_DEB" Version | tr -d '\r\n')" = '3.5.9'
test "$(dpkg-deb -f "$TMP_DEB" Architecture | tr -d '\r\n')" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP_DEB"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.5.9'

test -s "$PREFS_BIN"
test -s "$ROOT_PLIST"
test -s "$SPRINGY_CATALOG"
test -s "$SNOWBOARD_CATALOG"
test -s "$PREVIEW_MANIFEST"
test -d "$PREVIEW_ROOT"
grep -Fq 'GIF2ANI 3.5.9' "$ROOT_PLIST"
grep -Fq '274-THEME ANIMATION GALLERY' "$ROOT_PLIST"
strings "$PREFS_BIN" > "$WORK/prefs-strings.txt"
grep -Fq "$ROOTLESS_PATH" "$WORK/prefs-strings.txt"
grep -Fq 'bundled-262-animated-download-previews-v359' "$WORK/prefs-strings.txt"
grep -Fq 'g2_showBundledAnimatedDownloadPreview' "$WORK/prefs-strings.txt"
echo 'installed_359_runtime_markers=passed'

python3 - "$PREVIEW_MANIFEST" "$PREVIEW_ROOT" "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" "$WORK/tests.psv" <<'PY'
import hashlib,json,pathlib,struct,sys
manifest_path,root_path,springy_path,snowboard_path,output_path=map(pathlib.Path,sys.argv[1:])
manifest=json.loads(manifest_path.read_text())
root=root_path
springy=json.loads(springy_path.read_text())
snowboard=json.loads(snowboard_path.read_text())
assert springy['count']==len(springy['themes'])==48
assert snowboard['packageCount']==7
assert snowboard['count']==len(snowboard['themes'])==160
assert manifest['count']==len(manifest['previews'])==262
assert len(list(root.glob('*.gif')))==262

def skip_subblocks(data,pos):
    while True:
        if pos>=len(data): raise ValueError('truncated subblocks')
        size=data[pos]; pos+=1
        if size==0: return pos
        pos+=size
        if pos>len(data): raise ValueError('truncated payload')

def gif_frames(data):
    if data[:6] not in (b'GIF87a',b'GIF89a') or len(data)<13: raise ValueError('bad GIF header')
    packed=data[10]
    pos=13
    if packed & 0x80:
        pos += 3 * (2 ** ((packed & 7) + 1))
    frames=0
    while pos<len(data):
        marker=data[pos]; pos+=1
        if marker==0x3B: break
        if marker==0x21:
            if pos>=len(data): raise ValueError('truncated extension')
            pos+=1
            pos=skip_subblocks(data,pos)
        elif marker==0x2C:
            if pos+9>len(data): raise ValueError('truncated image descriptor')
            packed=data[pos+8]
            pos+=9
            if packed & 0x80:
                pos += 3 * (2 ** ((packed & 7) + 1))
            if pos>=len(data): raise ValueError('missing LZW size')
            pos+=1
            pos=skip_subblocks(data,pos)
            frames+=1
        else:
            raise ValueError(f'unexpected GIF block {marker:#x}')
    return frames

records={record['identifier']:record for record in manifest['previews']}
total=0
minimum=10**9
maximum=0
for identifier,record in records.items():
    path=root/f'{identifier}.gif'
    data=path.read_bytes()
    assert len(data)==record['bytes'],identifier
    assert hashlib.sha256(data).hexdigest()==record['sha256'],identifier
    frames=gif_frames(data)
    assert frames==record['frames'],(identifier,frames,record['frames'])
    assert frames>=2,identifier
    total+=len(data); minimum=min(minimum,frames); maximum=max(maximum,frames)
assert total==manifest['totalBytes']
print(f'installed_animated_previews=262|bytes={total}|minimum_frames={minimum}|maximum_frames={maximum}')

sp=next(x for x in springy['themes'] if x['name']=='Gameboy Advance')
sb=next(x for x in snowboard['themes'] if x['package']=='com.thwlfu.cakrespring')
rows=[]
for kind,theme in [('springy',sp),('snowboard',sb)]:
    preview=records[theme['identifier']]
    subpath=theme.get('archiveSubpath') or '__ROOT__'
    values=[kind,theme['package'],str(theme['bytes']),theme['sha256'],theme['downloadURL'],subpath,theme['name'],theme['identifier'],str(preview['frames']),str(preview['bytes']),preview['sha256']]
    assert all('|' not in value and '\n' not in value for value in values)
    rows.append('|'.join(values))
    print(f"sample_preview={theme['identifier']}|frames={preview['frames']}|bytes={preview['bytes']}")
output_path.write_text('\n'.join(rows)+'\n')
PY

mkdir -p "$MEDIA_ROOT" "$OPEN_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
find "$MEDIA_ROOT" -type d -exec chmod 0755 {} +
find "$MEDIA_ROOT" -type f -exec chmod 0644 {} +
find "$OPEN_ROOT" -maxdepth 1 -type d -name '.download-*' -exec rm -rf {} + 2>/dev/null || true
rm -f "$DIAGNOSTIC"

INDEX=0
while IFS='|' read -r KIND EXPECTED_PACKAGE EXPECTED_BYTES EXPECTED_SHA DOWNLOAD_URL ARCHIVE_SUBPATH DISPLAY_NAME IDENTIFIER PREVIEW_FRAMES PREVIEW_BYTES PREVIEW_SHA; do
  INDEX=$((INDEX + 1))
  CASE_DIR="$WORK/$KIND"
  DEB="$CASE_DIR/theme.deb"
  LISTING="$CASE_DIR/archive.list"
  LISTING_ERR="$CASE_DIR/archive-list.stderr"
  EXTRACTED="$CASE_DIR/extracted"
  mkdir -p "$CASE_DIR" "$EXTRACTED"
  chown -R mobile:mobile "$CASE_DIR"

  printf '%s_test_name=%s\n' "$KIND" "$DISPLAY_NAME"
  EFFECTIVE="$(sudo -u mobile curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 300 --output "$DEB" --write-out '%{url_effective}' "$DOWNLOAD_URL")"
  printf '%s_effective_url=%s\n' "$KIND" "$EFFECTIVE"
  ACTUAL_BYTES="$(wc -c < "$DEB" | tr -d ' ')"
  ACTUAL_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
  OWNER_UID="$(ls -dn "$DEB" | awk '{print $3}')"
  test "$ACTUAL_BYTES" = "$EXPECTED_BYTES"
  test "$ACTUAL_SHA" = "$EXPECTED_SHA"
  test "$OWNER_UID" = '501'

  set +e
  sudo -u mobile env -i PATH='/usr/bin:/bin' HOME=/var/mobile TMPDIR=/tmp LC_ALL=C /var/jb/usr/bin/dpkg-deb -c "$DEB" > "$CASE_DIR/old-env.list" 2> "$CASE_DIR/old-env.stderr"
  OLD_ENV_STATUS=$?
  set -e
  printf '%s_old_restricted_environment_status=%s\n' "$KIND" "$OLD_ENV_STATUS"

  sudo -u mobile env -i PATH="$ROOTLESS_PATH" HOME=/var/mobile TMPDIR=/tmp LC_ALL=C /var/jb/usr/bin/dpkg-deb -c "$DEB" > "$LISTING" 2> "$LISTING_ERR"
  PREFLIGHT_STATUS=$?
  printf '%s_preferences_environment_preflight_status=%s\n' "$KIND" "$PREFLIGHT_STATUS"
  test "$PREFLIGHT_STATUS" -eq 0
  test -s "$LISTING"

  PACKAGE_ID="$(sudo -u mobile env -i PATH="$ROOTLESS_PATH" HOME=/var/mobile TMPDIR=/tmp LC_ALL=C /var/jb/usr/bin/dpkg-deb -f "$DEB" Package | tr -d '\r\n')"
  printf '%s_expected_package=%s\n' "$KIND" "$EXPECTED_PACKAGE"
  printf '%s_actual_package=%s\n' "$KIND" "$PACKAGE_ID"
  test "$PACKAGE_ID" = "$EXPECTED_PACKAGE"

  rm -rf "$EXTRACTED"
  mkdir -p "$EXTRACTED"
  chown mobile:mobile "$EXTRACTED"
  sudo -u mobile env -i PATH="$ROOTLESS_PATH" HOME=/var/mobile TMPDIR=/tmp LC_ALL=C /var/jb/usr/bin/dpkg-deb -x "$DEB" "$EXTRACTED"
  EXTRACT_STATUS=$?
  printf '%s_preferences_environment_extract_status=%s\n' "$KIND" "$EXTRACT_STATUS"
  test "$EXTRACT_STATUS" -eq 0

  if [ "$ARCHIVE_SUBPATH" = '__ROOT__' ]; then
    MEDIA_AREA="$EXTRACTED"
    printf '%s_archive_subpath=package_root\n' "$KIND"
  else
    MEDIA_AREA="$EXTRACTED/$ARCHIVE_SUBPATH"
    printf '%s_archive_subpath=%s\n' "$KIND" "$ARCHIVE_SUBPATH"
    test -d "$MEDIA_AREA"
  fi
  MEDIA_COUNT="$(find "$MEDIA_AREA" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
  printf '%s_media_count=%s\n' "$KIND" "$MEDIA_COUNT"
  test "$MEDIA_COUNT" -ge 1
  printf '%s_preview=%s|frames=%s|bytes=%s|sha256=%s\n' "$KIND" "$IDENTIFIER" "$PREVIEW_FRAMES" "$PREVIEW_BYTES" "$PREVIEW_SHA"
  echo "${KIND}_settings_archive_runtime=passed"
done < "$WORK/tests.psv"
test "$INDEX" = '2'

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 8
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_8s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.5.9'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
printf 'gallery_label='; grep -o '[0-9]*-THEME ANIMATION GALLERY' "$ROOT_PLIST" | head -n 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi

echo 'gif2ani_359_install=success'
echo 'gif2ani_359_all_262_animated_previews=success'
echo 'gif2ani_359_checkra1n_settings_archive_runtime=success'
echo 'gif2ani_359_gameboy_advance_settings_archive_runtime=success'
echo 'gif2ani_359_gallery_total_274=success'
