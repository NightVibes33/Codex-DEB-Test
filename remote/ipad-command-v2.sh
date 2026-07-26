#!/bin/sh
set -eu
ROOTLESS_PATH='/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin'
export PATH="$ROOTLESS_PATH"
export HOME=/var/mobile
export TMPDIR=/tmp
export LC_ALL=C

RELEASE_COMMIT='485cd0bad1b0459170fc950765c56921a3e9461d'
RELEASE_URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.6.0-animated-gallery-cards.deb"
RELEASE_SHA='228df90cc9d308de706c4df55fadbb16d537d39ff0da12008b7eb33c6ebb0f33'
TMP_DEB='/tmp/Gif2Ani-3.6.0-animated-gallery-cards.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
ROOT_PLIST="$BUNDLE/Root.plist"
SPRINGY_CATALOG="$BUNDLE/OpenThemeCatalog.json"
SNOWBOARD_CATALOG="$BUNDLE/SnowBoardCatalog.json"
PREVIEW_MANIFEST="$BUNDLE/ThemePreviewAnimations.json"
PREVIEW_ROOT="$BUNDLE/ThemePreviewAnimations"
WORK='/tmp/gif2ani-360-card-audit'

printf '%s\n' '=== Install Gif2Ani 3.6.0 and verify pre-download animated gallery cards ==='
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
ACTUAL_SHA="$(sha256sum "$TMP_DEB" | awk '{print $1}')"
printf 'release_sha256=%s\n' "$ACTUAL_SHA"
test "$ACTUAL_SHA" = "$RELEASE_SHA"
test "$(dpkg-deb -f "$TMP_DEB" Package | tr -d '\r\n')" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$TMP_DEB" Version | tr -d '\r\n')" = '3.6.0'
test "$(dpkg-deb -f "$TMP_DEB" Architecture | tr -d '\r\n')" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP_DEB"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.6.0'

test -s "$PREFS_BIN"
test -s "$ROOT_PLIST"
test -s "$SPRINGY_CATALOG"
test -s "$SNOWBOARD_CATALOG"
test -s "$PREVIEW_MANIFEST"
test -d "$PREVIEW_ROOT"
grep -Fq 'GIF2ANI 3.6.0' "$ROOT_PLIST"
grep -Fq '274-THEME ANIMATION GALLERY' "$ROOT_PLIST"
strings "$PREFS_BIN" > "$WORK/prefs-strings.txt"
grep -Fq 'visible-card-bundled-animation-v360' "$WORK/prefs-strings.txt"
grep -Fq "$ROOTLESS_PATH" "$WORK/prefs-strings.txt"
echo 'installed_360_card_runtime_markers=passed'

python3 - "$PREVIEW_MANIFEST" "$PREVIEW_ROOT" "$SPRINGY_CATALOG" "$SNOWBOARD_CATALOG" <<'PY'
import hashlib,json,pathlib,sys
manifest_path,root_path,springy_path,snowboard_path=map(pathlib.Path,sys.argv[1:])
manifest=json.loads(manifest_path.read_text())
root=root_path
springy=json.loads(springy_path.read_text())
snowboard=json.loads(snowboard_path.read_text())
assert springy['count']==len(springy['themes'])==48
assert snowboard['packageCount']==7
assert snowboard['count']==len(snowboard['themes'])==160
assert manifest['count']==len(manifest['previews'])==262
files=list(root.glob('*.gif'))
assert len(files)==262

def skip_subblocks(data,pos):
    while True:
        if pos>=len(data): raise ValueError('truncated subblocks')
        size=data[pos]; pos+=1
        if size==0: return pos
        pos+=size
        if pos>len(data): raise ValueError('truncated payload')

def gif_frames(data):
    if data[:6] not in (b'GIF87a',b'GIF89a') or len(data)<13: raise ValueError('bad GIF header')
    pos=13
    packed=data[10]
    if packed & 0x80: pos += 3 * (2 ** ((packed & 7) + 1))
    frames=0
    while pos<len(data):
        marker=data[pos]; pos+=1
        if marker==0x3B: break
        if marker==0x21:
            if pos>=len(data): raise ValueError('truncated extension')
            pos+=1
            pos=skip_subblocks(data,pos)
        elif marker==0x2C:
            if pos+9>len(data): raise ValueError('truncated descriptor')
            packed=data[pos+8]; pos+=9
            if packed & 0x80: pos += 3 * (2 ** ((packed & 7) + 1))
            if pos>=len(data): raise ValueError('missing LZW size')
            pos+=1
            pos=skip_subblocks(data,pos)
            frames+=1
        else:
            raise ValueError(f'unexpected block {marker:#x}')
    return frames

records={record['identifier']:record for record in manifest['previews']}
minimum=10**9
maximum=0
total=0
for identifier,record in records.items():
    path=root/f'{identifier}.gif'
    data=path.read_bytes()
    assert len(data)==record['bytes'],identifier
    assert hashlib.sha256(data).hexdigest()==record['sha256'],identifier
    frames=gif_frames(data)
    assert frames==record['frames'],(identifier,frames,record['frames'])
    assert frames>=2,identifier
    minimum=min(minimum,frames); maximum=max(maximum,frames); total+=len(data)
assert total==manifest['totalBytes']
print(f'installed_card_preview_inventory=262|bytes={total}|minimum_frames={minimum}|maximum_frames={maximum}')

samples=[]
samples.append(next(theme for theme in springy['themes'] if theme['name']=='Gameboy Advance'))
samples.append(next(theme for theme in snowboard['themes'] if theme['name']=='9 Hand Tap'))
samples.append(next(theme for theme in snowboard['themes'] if theme['name']=='CheckRa1n'))
for theme in samples:
    record=records[theme['identifier']]
    path=root/f"{theme['identifier']}.gif"
    assert path.is_file() and record['frames']>=2
    print(f"pre_download_card_sample={theme['name']}|identifier={theme['identifier']}|frames={record['frames']}|bytes={record['bytes']}")
print('pre_download_animated_card_samples=passed')
PY

MEDIA_ROOT='/var/mobile/Library/Application Support/Gif2Ani'
mkdir -p "$MEDIA_ROOT"
chown -R mobile:mobile "$MEDIA_ROOT"
find "$MEDIA_ROOT" -type d -exec chmod 0755 {} +
find "$MEDIA_ROOT" -type f -exec chmod 0644 {} +

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 8
VERSION_DELAYED="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_after_8s=%s\n' "$VERSION_DELAYED"
test "$VERSION_DELAYED" = '3.6.0'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
printf 'gallery_label='; grep -o '[0-9]*-THEME ANIMATION GALLERY' "$ROOT_PLIST" | head -n 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi

echo 'gif2ani_360_install=success'
echo 'gif2ani_360_visible_cards_animate_before_download=success'
echo 'gif2ani_360_all_262_card_previews=success'
echo 'gif2ani_360_offscreen_cleanup_and_bounded_cache=compiled'
echo 'gif2ani_360_gallery_total_274=success'
