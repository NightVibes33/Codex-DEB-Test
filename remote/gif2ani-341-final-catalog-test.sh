#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

PAYLOAD_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/main/remote/payloads/Gif2Ani-3.4.1-rootless.deb'
EXPECTED_DEB_SHA256='07e8e0cd8c51d18b3d2f3ba61617972717d04837e2bf22b5637018e99574ae8f'
WORK='/var/mobile/Library/Caches/Gif2Ani341FinalCatalogTest'
DEB="$WORK/Gif2Ani-3.4.1-rootless.deb"
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
CATALOG="$BUNDLE/OpenThemeCatalog.json"
LIBRARY='/var/mobile/Library/Application Support/Gif2Ani/OpenThemeLibrary'
ACTIVE='/var/mobile/Library/Application Support/Gif2Ani/Active.gif'
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
BACKUP="$WORK/cache-backup"
SUCCESS=0

sha_file() {
  if [ -f "$1" ]; then sha256sum "$1" | awk '{print $1}'; else printf 'MISSING'; fi
}

restore_cache() {
  for package in io.github.virenmohindra.a-wave io.github.virenmohindra.swish; do
    final="$LIBRARY/$package"
    saved="$BACKUP/$package"
    rm -rf "$final"
    if [ -d "$saved" ]; then mv "$saved" "$final"; fi
  done
}

finish() {
  code=$?
  trap - EXIT INT TERM
  if [ "$SUCCESS" -ne 1 ]; then
    echo 'catalog_test_rollback=starting'
    restore_cache || true
    echo 'catalog_test_rollback=complete'
  fi
  rm -rf "$WORK/downloads" "$WORK/extracted" "$DEB" "$WORK/selected-packs.txt" 2>/dev/null || true
  exit "$code"
}
trap finish EXIT INT TERM

rm -rf "$WORK"
mkdir -p "$WORK/downloads" "$WORK/extracted" "$BACKUP" "$LIBRARY"
chown 501:501 "$LIBRARY" 2>/dev/null || true
chmod 0755 "$LIBRARY" 2>/dev/null || true

ORIGINAL_ACTIVE_SHA="$(sha_file "$ACTIVE")"
ORIGINAL_PREFS_SHA="$(sha_file "$PREFS")"
printf '%s\n' '=== Gif2Ani 3.4.1 final catalog install/test ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'original_active_sha256=%s\n' "$ORIGINAL_ACTIVE_SHA"
printf 'original_preferences_sha256=%s\n' "$ORIGINAL_PREFS_SHA"

for package in io.github.virenmohindra.a-wave io.github.virenmohindra.swish; do
  if [ -d "$LIBRARY/$package" ]; then mv "$LIBRARY/$package" "$BACKUP/$package"; fi
done

printf '%s\n' '=== Download and reinstall final verified DEB ==='
curl -fL --connect-timeout 25 --max-time 180 --retry 4 --retry-delay 2 "$PAYLOAD_URL" -o "$DEB"
test -s "$DEB"
ACTUAL_DEB_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
printf 'downloaded_deb_sha256=%s\n' "$ACTUAL_DEB_SHA"
test "$ACTUAL_DEB_SHA" = "$EXPECTED_DEB_SHA256"
test "$(dpkg-deb -f "$DEB" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$DEB" Version)" = '3.4.1'
test "$(dpkg-deb -f "$DEB" Architecture)" = 'iphoneos-arm64'
dpkg -i "$DEB"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.4.1'
test -s "$BUNDLE/Gif2AniPrefs"
test -s "$CATALOG"
echo 'final_package_install=passed'

python3 - "$CATALOG" "$WORK/selected-packs.txt" <<'PY'
import json,sys
catalog_path,out_path=sys.argv[1:3]
data=json.load(open(catalog_path))
assert data['count']==len(data['themes'])==48
assert data['liveSnapshotCount']==48
assert data['repositoryIndexMismatchCount']==47
assert data['missingPagesPayloadFallbackCount']==1
assert data['sourceRepository']=='VirenMohindra/CydiaRepo'
selected=[]
for package in ['io.github.virenmohindra.a-wave','io.github.virenmohindra.swish']:
    matches=[item for item in data['themes'] if item['package']==package]
    assert len(matches)==1
    item=matches[0]
    assert len(item['sha256'])==64
    assert int(item['bytes'])>0
    assert int(item['verifiedMediaFiles'])>=1
    selected.append(item)
assert selected[0]['downloadURL'].startswith('https://virenmohindra.github.io/debs/')
assert selected[0]['sha256']=='853d01e5a41092561d47dc6ccfc87b9e547dd926b7ba1daa9980fe148e276279'
assert int(selected[0]['bytes'])==2971658
assert selected[1]['downloadURL']=='https://raw.githubusercontent.com/VirenMohindra/CydiaRepo/c507a391f193c2bb362ff77fc1c1673c0da2dcae/debs/io.github.virenmohindra.swish_2.0_iphoneos-arm.deb'
assert selected[1]['sha256']=='9222d95626886b0b1c81e06077f3d25a0a2e57e46302d19d088a45206439b8b5'
assert int(selected[1]['bytes'])==988034
with open(out_path,'w') as out:
    for item in selected:
        fields=[item['package'],item.get('version',''),item['downloadURL'],item['sha256'],str(item['bytes']),item.get('source',"Viren's Repo"),item.get('sourceLicense','MIT')]
        assert all('\t' not in str(value) and '\n' not in str(value) for value in fields)
        out.write('\t'.join(str(value) for value in fields)+'\n')
print('installed_verified_springy_catalog=48')
print('selected_source_pack_tests=2')
PY

validate_and_normalize_pack() {
  package="$1"
  version="$2"
  url="$3"
  expected_sha="$4"
  expected_bytes="$5"
  source_name="$6"
  license_name="$7"
  safe_name="$(printf '%s' "$package" | tr -c 'A-Za-z0-9.-' '_')"
  archive="$WORK/downloads/$safe_name.deb"
  extract="$WORK/extracted/$safe_name"
  final="$LIBRARY/$package"

  printf '%s\n' "=== source_pack_begin=$package ==="
  case "$url" in
    https://virenmohindra.github.io/debs/*.deb) ;;
    https://raw.githubusercontent.com/VirenMohindra/CydiaRepo/c507a391f193c2bb362ff77fc1c1673c0da2dcae/debs/*.deb) ;;
    *) echo "source_pack_failure=blocked_url:$url"; return 91 ;;
  esac

  curl -fL --connect-timeout 20 --max-time 240 --retry 4 --retry-delay 2 "$url" -o "$archive"
  actual_bytes="$(wc -c < "$archive" | tr -d ' ')"
  actual_sha="$(sha256sum "$archive" | awk '{print $1}')"
  actual_package="$(dpkg-deb -f "$archive" Package)"
  printf 'source_pack=%s\nactual_bytes=%s\nexpected_bytes=%s\nactual_sha256=%s\nexpected_sha256=%s\nactual_package=%s\n' \
    "$package" "$actual_bytes" "$expected_bytes" "$actual_sha" "$expected_sha" "$actual_package"
  test "$actual_bytes" = "$expected_bytes"
  test "$actual_sha" = "$expected_sha"
  test "$actual_package" = "$package"

  dpkg-deb -c "$archive" > "$WORK/$safe_name-listing.txt"
  python3 - "$WORK/$safe_name-listing.txt" <<'PY'
import sys
for raw in open(sys.argv[1],errors='replace'):
    parts=raw.rstrip('\n').split(maxsplit=5)
    if len(parts)<6: continue
    mode,path=parts[0],parts[5].split(' -> ',1)[0]
    if mode[:1] in {'l','h','c','b','p','s'}:
        raise SystemExit('unsafe_special_file='+mode+':'+path)
    if not path.startswith('./') or '/../' in path or path.startswith('./../') or '\\' in path:
        raise SystemExit('unsafe_archive_path='+path)
print('archive_preflight=passed')
PY

  rm -rf "$extract"
  mkdir -p "$extract"
  dpkg-deb -x "$archive" "$extract"

  python3 - "$extract" "$final" "$package" "$version" "$expected_sha" "$source_name" "$license_name" <<'PY'
import json,math,os,pathlib,plistlib,shutil,sys,time,uuid
root=pathlib.Path(sys.argv[1]).resolve()
final=pathlib.Path(sys.argv[2])
package,version,sha,source,license_name=sys.argv[3:8]
allowed={'.gif','.png','.jpg','.jpeg','.webp'}
files=[]
total=0
for path in root.rglob('*'):
    if path.is_symlink(): raise SystemExit('unsafe_extracted_symlink='+str(path))
    if path.is_file():
        files.append(path)
        total+=path.stat().st_size
        if len(files)>1000: raise SystemExit('unsafe_file_count')
        if total>512*1024*1024: raise SystemExit('unsafe_extracted_size')
media=[path for path in files if path.suffix.lower() in allowed]
if not media: raise SystemExit('no_previewable_media')

def score(path,count,is_gif):
    lower=str(path).lower()
    value=100000 if is_gif else min(5000,count)*10
    if 'springy' in lower: value+=4000
    if 'respring' in lower: value+=3500
    if 'bootlogo' in lower: value+=3000
    if 'animation' in lower: value+=1500
    if 'preview' in lower or 'icon' in lower: value-=5000
    return value

best=None
best_score=-10**9
by_dir={}
for path in media: by_dir.setdefault(path.parent,[]).append(path)
for directory,items in by_dir.items():
    items=sorted(items,key=lambda p:p.name.lower())
    for path in items:
        if path.suffix.lower()=='.gif':
            header=path.read_bytes()[:6]
            if header in (b'GIF87a',b'GIF89a'):
                value=score(path,1,True)
                if value>best_score: best=('gif',path,[path]); best_score=value
    if len(items)>=2:
        value=score(directory,len(items),False)
        if value>best_score: best=('frames',directory,items); best_score=value
if best is None: raise SystemExit('no_compatible_animation_candidate')
kind,source_path,items=best
staging=final.parent/('.ready-'+str(uuid.uuid4()))
shutil.rmtree(staging,ignore_errors=True)
staging.mkdir(parents=True,mode=0o755)
if kind=='gif':
    relative='Animation.gif'
    shutil.copy2(source_path,staging/relative)
    if (staging/relative).read_bytes()[:6] not in (b'GIF87a',b'GIF89a'): raise SystemExit('normalized_gif_invalid')
    normalized_count=1
else:
    relative='Frames'
    destination=staging/relative
    destination.mkdir(mode=0o755)
    output_count=min(len(items),240)
    selected=[]
    for output_index in range(output_count):
        source_index=output_index
        if len(items)>output_count and output_count>1:
            source_index=round((output_index*(len(items)-1))/(output_count-1))
        selected.append(items[source_index])
    for index,path in enumerate(selected):
        ext=path.suffix.lower().lstrip('.') or 'png'
        shutil.copy2(path,destination/f'{index:04d}.{ext}')
    normalized_count=len(list(destination.iterdir()))
    if normalized_count<2: raise SystemExit('normalized_frame_count_too_small')
metadata={
    'package':package,
    'version':version,
    'sha256':sha,
    'kind':kind,
    'relativePath':relative,
    'source':source,
    'license':license_name,
    'cachedAt':time.time(),
}
with open(staging/'metadata.plist','wb') as handle: plistlib.dump(metadata,handle,fmt=plistlib.FMT_BINARY)
backup=final.with_name(final.name+'.old')
shutil.rmtree(backup,ignore_errors=True)
if final.exists(): final.rename(backup)
try:
    staging.rename(final)
except Exception:
    if backup.exists(): backup.rename(final)
    raise
shutil.rmtree(backup,ignore_errors=True)
for directory,dirs,names in os.walk(final):
    os.chown(directory,501,501); os.chmod(directory,0o755)
    for name in names:
        path=os.path.join(directory,name); os.chown(path,501,501); os.chmod(path,0o644)
print('extracted_file_count='+str(len(files)))
print('previewable_media_count='+str(len(media)))
print('selected_kind='+kind)
print('selected_source_path='+str(source_path.relative_to(root)))
print('normalized_media_count='+str(normalized_count))
print('normalized_cache='+str(final))
PY

  python3 - "$final/metadata.plist" "$final" "$package" "$expected_sha" <<'PY'
import pathlib,plistlib,sys
meta_path,root_path,package,sha=sys.argv[1:5]
root=pathlib.Path(root_path)
with open(meta_path,'rb') as handle: data=plistlib.load(handle)
assert data['package']==package
assert data['sha256']==sha
assert data['kind'] in {'gif','frames'}
target=(root/data['relativePath']).resolve()
assert str(target).startswith(str(root.resolve())+'/')
if data['kind']=='gif':
    assert target.is_file() and target.read_bytes()[:6] in (b'GIF87a',b'GIF89a')
else:
    assert target.is_dir() and len([p for p in target.iterdir() if p.is_file()])>=2
print('gallery_cache_metadata=passed')
print('gallery_cached_kind='+data['kind'])
print('gallery_cached_path='+str(target))
PY
  printf 'source_pack_test=%s:passed\n' "$package"
}

while IFS="$(printf '\t')" read -r package version url expected_sha expected_bytes source_name license_name; do
  validate_and_normalize_pack "$package" "$version" "$url" "$expected_sha" "$expected_bytes" "$source_name" "$license_name"
done < "$WORK/selected-packs.txt"

FINAL_ACTIVE_SHA="$(sha_file "$ACTIVE")"
FINAL_PREFS_SHA="$(sha_file "$PREFS")"
printf 'final_active_sha256=%s\n' "$FINAL_ACTIVE_SHA"
printf 'final_preferences_sha256=%s\n' "$FINAL_PREFS_SHA"
test "$FINAL_ACTIVE_SHA" = "$ORIGINAL_ACTIVE_SHA"
test "$FINAL_PREFS_SHA" = "$ORIGINAL_PREFS_SHA"

rm -rf "$BACKUP"
killall -9 Preferences 2>/dev/null || true
if command -v uiopen >/dev/null 2>&1; then
  su mobile -c "uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true
fi
sleep 4

SUCCESS=1
echo 'final_catalog_device_test=success'
echo 'final_deb_installed=true'
echo 'verified_springy_catalog=48'
echo 'source_packs_downloaded_and_cached=2'
echo 'a_wave_cache_ready=true'
echo 'swish_cache_ready=true'
echo 'active_animation_unchanged=true'
echo 'preferences_unchanged=true'
printf 'completed_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
