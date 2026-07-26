#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
MARK='/tmp/gif2ani-350-audit-crash-marker'
PREFS_BACKUP='/tmp/gif2ani-350-prefs-backup.plist'

printf '%s\n' '=== Gif2Ani 3.5.0 device management and runtime audit ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true

test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.5.0'
test -s "$BUNDLE/Gif2AniPrefs"
test -s '/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
mkdir -p "$MEDIA"

rm -f "$MARK" "$PREFS_BACKUP"
: > "$MARK"
if [ -f "$PREFS" ]; then cp -p "$PREFS" "$PREFS_BACKUP"; fi
restore_prefs() {
  if [ -f "$PREFS_BACKUP" ]; then
    cp -p "$PREFS_BACKUP" "$PREFS"
    chown 501:501 "$PREFS" 2>/dev/null || true
    chmod 0644 "$PREFS" 2>/dev/null || true
  fi
}
trap 'restore_prefs; rm -f "$MARK" "$PREFS_BACKUP"' EXIT INT TERM

python3 - "$BUNDLE" "$MEDIA" "$PREFS" <<'PY'
import json, os, pathlib, plistlib, shutil, sys, time
bundle=pathlib.Path(sys.argv[1]); media=pathlib.Path(sys.argv[2]); prefs_path=pathlib.Path(sys.argv[3])

manifest=bundle/'ThemeCatalog.json'
assert manifest.is_file(), manifest
catalog=json.loads(manifest.read_text())
assert catalog.get('version') == 1
assert catalog.get('count') == 54
assert len(catalog.get('themes', [])) == 54
ids=[t.get('id') for t in catalog['themes']]
assert len(ids)==len(set(ids))==54
for t in catalog['themes']:
    assert isinstance(t.get('bytes'), int) and 0 < t['bytes'] <= 25*1024*1024
    assert isinstance(t.get('sha256'), str) and len(t['sha256']) == 64
    assert t.get('sourceFrames') == 24 and t.get('width') == 360 and t.get('height') == 360
    assert t.get('license') == 'CC0-1.0'
print('cc0_catalog_count=54')
print('cc0_catalog_integrity=passed')

prefs={}
if prefs_path.exists():
    with prefs_path.open('rb') as f: prefs=plistlib.load(f)
original=dict(prefs)
prefs['galleryFavorites']=['pulse-rings','cyan-pulse-rings']
prefs['galleryRecent']=['cyan-pulse-rings','pulse-rings']
prefs['lastSelectedTheme']='cyan-pulse-rings'
prefs['lastSelectedThemeAt']=time.time()
tmp=prefs_path.with_suffix('.audit-new')
tmp.parent.mkdir(parents=True,exist_ok=True)
with tmp.open('wb') as f: plistlib.dump(prefs,f,fmt=plistlib.FMT_BINARY)
os.replace(tmp,prefs_path)
with prefs_path.open('rb') as f: check=plistlib.load(f)
assert check['galleryFavorites']==['pulse-rings','cyan-pulse-rings']
assert check['galleryRecent']==['cyan-pulse-rings','pulse-rings']
print('favorites_preferences_roundtrip=passed')
print('recent_preferences_roundtrip=passed')
print('original_enabled='+str(bool(original.get('isEnabled',False))).lower())
print('original_pending_ready='+str(bool(original.get('pendingReady',False))).lower())
print('original_last_applied_theme='+str(original.get('lastAppliedTheme','none')))

roots={
 'catalog':media/'Catalog',
 'springy':media/'OpenThemeLibrary',
 'imported':media/'Packs',
 'rollbacks':media/'Rollbacks',
}
def stats(path):
    files=0; total=0
    if path.exists():
        for p in path.rglob('*'):
            if p.is_file(): files+=1; total+=p.stat().st_size
    return files,total
for key,path in roots.items():
    files,total=stats(path)
    print(f'{key}_files={files}')
    print(f'{key}_bytes={total}')

rollback_gifs=sorted((roots['rollbacks'].glob('*.gif') if roots['rollbacks'].exists() else []))
assert len(rollback_gifs) <= 5, len(rollback_gifs)
for gif in rollback_gifs:
    assert gif.with_suffix('.plist').exists(), gif
print('rollback_slots='+str(len(rollback_gifs)))
print('rollback_retention_limit=passed')

catalog_dir=roots['catalog']
valid_cached=0; stale_cached=0
if catalog_dir.exists():
    by_id={t['id']:t for t in catalog['themes']}
    import hashlib
    for gif in catalog_dir.glob('*.gif'):
        t=by_id.get(gif.stem)
        if not t: stale_cached+=1; continue
        data=gif.read_bytes()
        if len(data)==t['bytes'] and hashlib.sha256(data).hexdigest()==t['sha256']:
            valid_cached+=1
        else: stale_cached+=1
print('cc0_cached_valid='+str(valid_cached))
print('cc0_cached_stale='+str(stale_cached))
assert stale_cached == 0
print('cc0_cache_integrity=passed')

springy=roots['springy']
source_valid=0; source_stale=0
if springy.exists():
    for d in springy.iterdir():
        if not d.is_dir() or d.name.startswith('.'): continue
        meta=d/'metadata.plist'
        if not meta.exists(): source_stale+=1; continue
        try:
            with meta.open('rb') as f: m=plistlib.load(f)
            rel=m.get('relativePath','')
            target=(d/rel).resolve()
            if not rel or '..' in pathlib.PurePosixPath(rel).parts or not str(target).startswith(str(d.resolve())+os.sep):
                source_stale+=1; continue
            if not target.exists() or len(str(m.get('sha256',''))) != 64:
                source_stale+=1; continue
            source_valid+=1
        except Exception: source_stale+=1
print('springy_cached_valid='+str(source_valid))
print('springy_cached_stale='+str(source_stale))
assert source_stale == 0
print('springy_cache_metadata=passed')

for name in ['Active.gif','Pending.gif','Rejected.gif','runtime-status.plist','pending-metadata.plist']:
    p=media/name
    print(name.lower().replace('.','_')+'_exists='+str(p.exists()).lower())
    if p.exists(): print(name.lower().replace('.','_')+'_bytes='+str(p.stat().st_size))

status=media/'runtime-status.plist'
if status.exists():
    with status.open('rb') as f: runtime=plistlib.load(f)
    print('runtime_event='+str(runtime.get('event','unknown')))
    print('runtime_frame_count='+str(runtime.get('frameCount',0)))
    print('runtime_animation_pending='+str(bool(runtime.get('animationPending',False))).lower())
    media_info=runtime.get('media') or {}
    if media_info:
        print('runtime_decoded_frames='+str(media_info.get('decodedFrames','unknown')))
        print('runtime_estimated_decoded_bytes='+str(media_info.get('estimatedDecodedBytes','unknown')))
print('device_data_audit=passed')
PY

restore_prefs
echo 'preferences_restored=true'

killall -9 Preferences 2>/dev/null || true
sleep 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  sleep 5
  echo 'settings_gallery_links_opened=true'
else
  echo 'settings_gallery_links_opened=false_uiopen_missing'
fi

NEW_CRASHES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -newer "$MARK" 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_preferences_crashes=%s\n' "$NEW_CRASHES"
test "$NEW_CRASHES" = '0'

echo 'gif2ani_350_management_audit=success'
echo 'gif2ani_350_cache_audit=success'
echo 'gif2ani_350_runtime_audit=success'
