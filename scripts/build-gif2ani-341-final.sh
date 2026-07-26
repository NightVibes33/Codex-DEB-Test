#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-darkboot}"
OUTPUT_DIR="${2:-$PWD}"
THEOS="${THEOS:-/opt/theos}"
export THEOS

cd "$SOURCE_DIR"

test "$(awk '/^Version:/{print $2}' control)" = "3.4.1"
test -f gif2aniprefs/G2ThemeGalleryController.m
test -f gif2aniprefs/G2RemoteThemeCatalog.inc
test -f gif2aniprefs/G2RemoteThemePreviewOverride.inc
test -f gif2aniprefs/G2OpenThemeLibrary.inc
test -f gif2aniprefs/G2BundledOpenThemeCatalog.inc
test -f gif2aniprefs/G2ThemeStageOverride.inc
test -f gif2aniprefs/Resources/ThemeCatalog.json
test -f gif2aniprefs/Resources/OpenThemeCatalog.json
grep -Fq '114-THEME ANIMATION GALLERY' gif2aniprefs/Resources/Root.plist
grep -Fq 'G2RemoteDataMatchesManifest' gif2aniprefs/G2RemoteThemePreviewOverride.inc
grep -Fq 'CC_SHA256' gif2aniprefs/G2RemoteThemePreviewOverride.inc
grep -Fq 'G2WriteGalleryPreferences(@{@"pendingReady":@YES}' gif2aniprefs/G2ThemeStageOverride.inc

python3 - <<'PY'
import json,re
from pathlib import Path

cc0=json.loads(Path('gif2aniprefs/Resources/ThemeCatalog.json').read_text())
opened=json.loads(Path('gif2aniprefs/Resources/OpenThemeCatalog.json').read_text())
assert cc0['version']==1
assert cc0['count']==len(cc0['themes'])==54
assert opened['version']==1
assert opened['count']==len(opened['themes'])==48
assert opened['sourceRepository']=='VirenMohindra/CydiaRepo'
assert opened['sourceLicense']=='MIT'
assert len({x['id'] for x in cc0['themes']})==54
assert len({x['package'] for x in opened['themes']})==48
for item in cc0['themes']:
    assert re.fullmatch(r'[a-z0-9-]+',item['id'])
    assert item['file']==item['id']+'.gif'
    assert re.fullmatch(r'[0-9a-f]{64}',item['sha256'])
    assert 0<int(item['bytes'])<=25*1024*1024
    assert item['sourceFrames']==24
    assert item['width']==360 and item['height']==360
    assert item['license']=='CC0-1.0'
for item in opened['themes']:
    assert item['identifier']==item['package']
    assert item['package'].startswith('io.github.virenmohindra.')
    assert item['downloadURL'].startswith('https://virenmohindra.github.io/debs/')
    assert re.fullmatch(r'[0-9a-f]{64}',item['sha256'])
    assert 0<int(item['bytes'])<=100*1024*1024
    assert item['sourceLicense']=='MIT'

wrapper=Path('gif2aniprefs/G2ThemeGalleryController.m').read_text()
openlib=Path('gif2aniprefs/G2OpenThemeLibrary.inc').read_text()
stage=Path('gif2aniprefs/G2ThemeStageOverride.inc').read_text()
for include in ['G2RemoteThemeCatalog.inc','G2BundledOpenThemeCatalog.inc','G2OpenThemeLibrary.inc','G2RemoteThemePreviewOverride.inc','G2RemoteGalleryPolish.inc']:
    assert f'#include "{include}"' in wrapper
assert 'G2PreflightArchive' in openlib
assert 'G2ValidateExtractedTree' in openlib
assert 'SHA-256 verification failed' in openlib
assert 'G2WriteGalleryPreferences(@{@"pendingReady":@YES}' in stage
assert 12+cc0['count']+opened['count']==114
print('offline_themes=12')
print('cc0_download_themes=54')
print('original_springy_themes=48')
print('first_class_theme_total=114')
print('source_contract=success')
PY

make clean package FINALPACKAGE=1 2>&1 | tee "$OUTPUT_DIR/gif2ani-341-final-build.log"
DEB="$(find packages -maxdepth 1 -type f -name 'com.nightvibes33.gif2ani_3.4.1_iphoneos-arm64.deb' -print -quit)"
test -n "$DEB"
cp "$DEB" "$OUTPUT_DIR/Gif2Ani-3.4.1-final.deb"

test "$(dpkg-deb --field "$DEB" Package)" = com.nightvibes33.gif2ani
test "$(dpkg-deb --field "$DEB" Version)" = 3.4.1
test "$(dpkg-deb --field "$DEB" Architecture)" = iphoneos-arm64

rm -rf "$OUTPUT_DIR/gif2ani-341-root"
dpkg-deb -x "$DEB" "$OUTPUT_DIR/gif2ani-341-root"
BUNDLE="$(find "$OUTPUT_DIR/gif2ani-341-root" -type d -name Gif2AniPrefs.bundle -print -quit)"
test -n "$BUNDLE"
test -s "$BUNDLE/Gif2AniPrefs"
test -f "$BUNDLE/Root.plist"
test -f "$BUNDLE/ThemeCatalog.json"
test -f "$BUNDLE/OpenThemeCatalog.json"
test -s "$OUTPUT_DIR/gif2ani-341-root/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib"

strings "$BUNDLE/Gif2AniPrefs" > "$OUTPUT_DIR/gif2ani-341-bundle-strings.txt"
grep -Fq 'SHA-256 does not match the pinned manifest' "$OUTPUT_DIR/gif2ani-341-bundle-strings.txt"
grep -Fq 'Open Source Pack Library' "$OUTPUT_DIR/gif2ani-341-bundle-strings.txt"
grep -Fq 'Original Springy pack' "$OUTPUT_DIR/gif2ani-341-bundle-strings.txt"

python3 - "$BUNDLE/ThemeCatalog.json" "$BUNDLE/OpenThemeCatalog.json" <<'PY'
import json,sys
cc0=json.load(open(sys.argv[1]))
opened=json.load(open(sys.argv[2]))
assert cc0['count']==len(cc0['themes'])==54
assert opened['count']==len(opened['themes'])==48
assert len({x['package'] for x in opened['themes']})==48
print('packaged_cc0_manifest=54')
print('packaged_open_manifest=48')
print('packaged_downloadable_total=102')
PY

sha256sum "$DEB" | tee "$OUTPUT_DIR/gif2ani-341-final-sha256.txt"
dpkg-deb --contents "$DEB" > "$OUTPUT_DIR/gif2ani-341-final-contents.txt"
file "$BUNDLE/Gif2AniPrefs" "$OUTPUT_DIR/gif2ani-341-root/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib" > "$OUTPUT_DIR/gif2ani-341-final-binaries.txt"
echo 'gif2ani_341_build=success'
