#!/bin/sh
set -eu
ROOTLESS_PATH='/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin'
export PATH="$ROOTLESS_PATH"
export HOME=/var/mobile
export TMPDIR=/tmp
export LC_ALL=C

RELEASE_COMMIT='215387f6d256bc389845a25e6852fe5311525a97'
RELEASE_URL="https://raw.githubusercontent.com/NightVibes33/Dark-Boot/$RELEASE_COMMIT/release-packages/Gif2Ani-3.6.1-color-faithful-previews.deb"
RELEASE_SHA='4ebea83c86820fd776dd9abfbfd70bf57658d51c0709809031b87f9cc8672044'
TMP_DEB='/tmp/Gif2Ani-3.6.1-color-faithful-previews.deb'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
PREFS_BIN="$BUNDLE/Gif2AniPrefs"
ROOT_PLIST="$BUNDLE/Root.plist"
PREVIEW_MANIFEST="$BUNDLE/ThemePreviewAnimations.json"
PREVIEW_ROOT="$BUNDLE/ThemePreviewAnimations"
WORK='/tmp/gif2ani-361-color-audit'

printf '%s\n' '=== Install Gif2Ani 3.6.1 and verify color-faithful pre-download previews ==='
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
test "$(dpkg-deb -f "$TMP_DEB" Version | tr -d '\r\n')" = '3.6.1'
test "$(dpkg-deb -f "$TMP_DEB" Architecture | tr -d '\r\n')" = 'iphoneos-arm64'
echo 'release_package_metadata=passed'

dpkg -i "$TMP_DEB"
VERSION_NOW="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'version_immediate=%s\n' "$VERSION_NOW"
test "$VERSION_NOW" = '3.6.1'

test -s "$PREFS_BIN"
test -s "$ROOT_PLIST"
test -s "$PREVIEW_MANIFEST"
test -d "$PREVIEW_ROOT"
grep -Fq 'GIF2ANI 3.6.1' "$ROOT_PLIST"
grep -Fq '274-THEME ANIMATION GALLERY' "$ROOT_PLIST"
strings "$PREFS_BIN" > "$WORK/prefs-strings.txt"
grep -Fq 'visible-card-bundled-animation-v360' "$WORK/prefs-strings.txt"
grep -Fq "$ROOTLESS_PATH" "$WORK/prefs-strings.txt"
echo 'installed_361_runtime_markers=passed'

python3 - "$PREVIEW_MANIFEST" "$PREVIEW_ROOT" <<'PY'
import hashlib,json,pathlib,sys
manifest_path,root_path=map(pathlib.Path,sys.argv[1:])
manifest=json.loads(manifest_path.read_text())
root=root_path
records=manifest['previews']
assert manifest['count']==len(records)==262
assert len(list(root.glob('*.gif')))==262
assert manifest['totalBytes']==sum(path.stat().st_size for path in root.glob('*.gif'))
assert all(record.get('paletteColors')==256 for record in records)
assert max(record['meanAbsoluteColorError'] for record in records)<=10.0
assert max(record['maximumFrameColorError'] for record in records)<=18.0

for record in records:
    path=root/f"{record['identifier']}.gif"
    data=path.read_bytes()
    assert len(data)==record['bytes'],record['identifier']
    assert hashlib.sha256(data).hexdigest()==record['sha256'],record['identifier']
    assert record['frames']>=2,record['identifier']

worst_mean=max(records,key=lambda x:x['meanAbsoluteColorError'])
worst_frame=max(records,key=lambda x:x['maximumFrameColorError'])
stranger=next(x for x in records if x['identifier']=='io.github.virenmohindra.stranger-things')
assert stranger['meanAbsoluteColorError']==0.0828
assert stranger['maximumFrameColorError']==0.0901
assert stranger['paletteColors']==256
assert stranger['frames']==10
print(f"installed_color_preview_inventory=262|bytes={manifest['totalBytes']}|palette_colors=256")
print(f"installed_worst_mean={worst_mean['identifier']}|{worst_mean['meanAbsoluteColorError']}")
print(f"installed_worst_frame={worst_frame['identifier']}|{worst_frame['maximumFrameColorError']}")
print(f"installed_stranger_things=frames={stranger['frames']}|bytes={stranger['bytes']}|mean_error={stranger['meanAbsoluteColorError']}|max_error={stranger['maximumFrameColorError']}")
print('installed_color_fidelity_gate=passed')
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
test "$VERSION_DELAYED" = '3.6.1'
printf 'visible_label='; grep -o 'GIF2ANI [0-9.]*' "$ROOT_PLIST" | head -n 1
printf 'gallery_label='; grep -o '[0-9]*-THEME ANIMATION GALLERY' "$ROOT_PLIST" | head -n 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  echo 'gif2ani_gallery_reopened=true'
fi

echo 'gif2ani_361_install=success'
echo 'gif2ani_361_all_262_color_faithful_previews=success'
echo 'gif2ani_361_stranger_things_color_fidelity=success'
echo 'gif2ani_361_gallery_total_274=success'
