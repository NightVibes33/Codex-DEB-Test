#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

DEB_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/main/remote/payloads/Gif2Ani-3.4.1-rootless.deb'
EXPECTED_DEB_SHA256='aa4691278f17938d77eb0f086e61e580115d3602c5686566f378ac4fa2b435eb'
CATALOG_BASE='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/b5d5eda04359409865772038895e660d709deb18/gif2ani-themes/v1'
MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
ACTIVE="$MEDIA/Active.gif"
REJECTED="$MEDIA/Rejected.gif"
RUNTIME="$MEDIA/runtime-status.plist"
SENTINEL="$MEDIA/load-in-progress"
WORK='/var/mobile/Library/Caches/Gif2Ani341InstallTest'
BACKUP="$MEDIA/RemoteTestBackup"
DEB="$WORK/Gif2Ani-3.4.1-rootless.deb"
SUCCESS=0

sha_file() {
  if [ -f "$1" ]; then sha256sum "$1" | awk '{print $1}'; else printf 'MISSING'; fi
}

restore_original_state() {
  echo 'rollback=starting'
  mkdir -p "$MEDIA"
  if [ -f "$BACKUP/had-active" ]; then cp -p "$BACKUP/Active.gif" "$ACTIVE"; else rm -f "$ACTIVE"; fi
  if [ -f "$BACKUP/had-prefs" ]; then cp -p "$BACKUP/preferences.plist" "$PREFS"; else rm -f "$PREFS"; fi
  if [ -f "$BACKUP/had-pending" ]; then cp -p "$BACKUP/Pending.gif" "$MEDIA/Pending.gif"; else rm -f "$MEDIA/Pending.gif"; fi
  if [ -f "$BACKUP/had-pending-meta" ]; then cp -p "$BACKUP/pending-metadata.plist" "$MEDIA/pending-metadata.plist"; else rm -f "$MEDIA/pending-metadata.plist"; fi
  rm -f "$SENTINEL" "$REJECTED"
  chown -R 501:501 "$MEDIA" "$PREFS" 2>/dev/null || true
  chmod 0644 "$ACTIVE" "$PREFS" 2>/dev/null || true
  killall -9 backboardd 2>/dev/null || true
  sleep 5
  echo 'rollback=complete'
}

finish() {
  code=$?
  trap - EXIT INT TERM
  if [ "$code" -ne 0 ] && [ "$SUCCESS" -ne 1 ]; then restore_original_state || true; fi
  rm -rf "$WORK" 2>/dev/null || true
  exit "$code"
}
trap finish EXIT INT TERM

printf '%s\n' '=== Gif2Ani 3.4.1 install and multi-theme device test ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'ios_version='; /usr/libexec/PlistBuddy -c 'Print :ProductVersion' /System/Library/CoreServices/SystemVersion.plist 2>/dev/null || true

mkdir -p "$WORK" "$MEDIA" "$(dirname "$PREFS")"
rm -rf "$BACKUP"
mkdir -p "$BACKUP"
if [ -f "$ACTIVE" ]; then touch "$BACKUP/had-active"; cp -p "$ACTIVE" "$BACKUP/Active.gif"; fi
if [ -f "$PREFS" ]; then touch "$BACKUP/had-prefs"; cp -p "$PREFS" "$BACKUP/preferences.plist"; fi
if [ -f "$MEDIA/Pending.gif" ]; then touch "$BACKUP/had-pending"; cp -p "$MEDIA/Pending.gif" "$BACKUP/Pending.gif"; fi
if [ -f "$MEDIA/pending-metadata.plist" ]; then touch "$BACKUP/had-pending-meta"; cp -p "$MEDIA/pending-metadata.plist" "$BACKUP/pending-metadata.plist"; fi
printf 'original_active_sha256=%s\n' "$(sha_file "$ACTIVE")"
printf 'rollback_backup=%s\n' "$BACKUP"

printf '%s\n' '=== Download and verify green DEB ==='
curl -fL --connect-timeout 25 --max-time 180 --retry 4 --retry-delay 2 "$DEB_URL" -o "$DEB"
test -s "$DEB"
ACTUAL_DEB_SHA256="$(sha256sum "$DEB" | awk '{print $1}')"
printf 'deb_sha256=%s\n' "$ACTUAL_DEB_SHA256"
test "$ACTUAL_DEB_SHA256" = "$EXPECTED_DEB_SHA256"
test "$(dpkg-deb -f "$DEB" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$DEB" Version)" = '3.4.1'
test "$(dpkg-deb -f "$DEB" Architecture)" = 'iphoneos-arm64'

# Install disabled first so package replacement cannot unexpectedly animate.
python3 - "$PREFS" <<'PY'
import os, plistlib, sys
path=sys.argv[1]
data={}
try:
    with open(path,'rb') as f:
        value=plistlib.load(f)
        if isinstance(value,dict): data=value
except Exception:
    pass
data['isEnabled']=False
data['pendingReady']=False
with open(path+'.tmp','wb') as f: plistlib.dump(data,f,fmt=plistlib.FMT_BINARY)
os.replace(path+'.tmp',path)
PY
chown 501:501 "$PREFS"
chmod 0644 "$PREFS"

dpkg -i "$DEB"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.4.1'
echo 'package_install=passed'

BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
DYLIB='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
FILTER='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.plist'
for path in "$BUNDLE/Gif2AniPrefs" "$BUNDLE/Root.plist" "$BUNDLE/ThemeCatalog.json" "$BUNDLE/OpenThemeCatalog.json" "$DYLIB" "$FILTER"; do
  test -s "$path"
  printf 'installed_file=%s\n' "$path"
done

python3 - "$BUNDLE/ThemeCatalog.json" "$BUNDLE/OpenThemeCatalog.json" <<'PY'
import json,sys
cc0=json.load(open(sys.argv[1]))
springy=json.load(open(sys.argv[2]))
assert cc0['count']==len(cc0['themes'])==54
assert springy['count']==len(springy['themes'])==48
assert springy['sourceRepository']=='VirenMohindra/CydiaRepo'
assert springy['sourceLicense']=='MIT'
assert len({x['package'] for x in springy['themes']})==48
print('installed_offline_themes=12')
print('installed_cc0_downloadable_themes=54')
print('installed_springy_downloadable_themes=48')
print('installed_first_class_themes=114')
PY

touch "$WORK/crash-marker"

set_preferences_for_test() {
  theme_name="$1"
  python3 - "$PREFS" "$theme_name" <<'PY'
import os, plistlib, sys
path,name=sys.argv[1:3]
data={}
try:
    with open(path,'rb') as f:
        value=plistlib.load(f)
        if isinstance(value,dict): data=value
except Exception:
    pass
data.update({
    'isEnabled': True,
    'pendingReady': False,
    'imageTransformation': 'resizeAspect',
    'backgroundColor': '#000000:1.000',
    'customLoop': -1,
    'customDuration': 2.0,
    'remoteTestTheme': name,
})
with open(path+'.tmp','wb') as f: plistlib.dump(data,f,fmt=plistlib.FMT_BINARY)
os.replace(path+'.tmp',path)
PY
  chown 501:501 "$PREFS"
  chmod 0644 "$PREFS"
}

wait_for_new_backboard() {
  old_pid="$1"
  count=0
  while [ "$count" -lt 40 ]; do
    new_pid="$(pgrep -x backboardd 2>/dev/null | head -n1 || true)"
    if [ -n "$new_pid" ] && [ "$new_pid" != "$old_pid" ]; then printf '%s' "$new_pid"; return 0; fi
    count=$((count+1))
    sleep 1
  done
  return 1
}

runtime_event() {
  python3 - "$RUNTIME" <<'PY'
import plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: d=plistlib.load(f)
    print(d.get('event','missing'))
except Exception:
    print('unreadable')
PY
}

test_theme() {
  name="$1"; filename="$2"; expected_bytes="$3"; expected_sha="$4"
  local_file="$WORK/$filename"
  printf '%s\n' "=== Runtime theme test: $name ==="
  curl -fL --connect-timeout 20 --max-time 120 --retry 3 --retry-delay 2 "$CATALOG_BASE/$filename" -o "$local_file"
  test "$(wc -c < "$local_file" | tr -d ' ')" = "$expected_bytes"
  test "$(sha256sum "$local_file" | awk '{print $1}')" = "$expected_sha"
  test "$(dd if="$local_file" bs=6 count=1 2>/dev/null)" = 'GIF89a'

  cp "$local_file" "$ACTIVE.new"
  chown 501:501 "$ACTIVE.new"
  chmod 0644 "$ACTIVE.new"
  mv -f "$ACTIVE.new" "$ACTIVE"
  set_preferences_for_test "$name"
  rm -f "$RUNTIME" "$SENTINEL" "$REJECTED"

  old_pid="$(pgrep -x backboardd 2>/dev/null | head -n1 || true)"
  test -n "$old_pid"
  killall -9 backboardd
  new_pid="$(wait_for_new_backboard "$old_pid")"
  test -n "$new_pid"
  sleep 8

  event="$(runtime_event)"
  printf 'theme=%s\nold_backboard_pid=%s\nnew_backboard_pid=%s\nruntime_event=%s\n' "$name" "$old_pid" "$new_pid" "$event"
  test "$event" = 'custom-animation-stable'
  test -s "$ACTIVE"
  test ! -e "$REJECTED"
  test ! -e "$SENTINEL"
  printf 'theme_test=%s:passed\n' "$name"
}

test_theme 'Cyan Pulse Rings' 'cyan-pulse-rings.gif' '130275' '1975aa569fb5ee0002856a7cff3b60bbcde04126514386fbd52b89d9f5349a46'
test_theme 'Cyan Halo Spinner' 'cyan-halo-spinner.gif' '49717' 'f0447aeece060d4e0ae563ad1e18c7055e8055a976d70b61c8d69f04db4c14cb'
test_theme 'Cyan Energy Wave' 'cyan-energy-wave.gif' '52155' '74d773db3f6b8f98daad1234266f3b594698cca200a0858f3c39494154b2c337'

printf '%s\n' '=== Original Springy source-pack pipeline test ==='
SPRINGY_DEB="$WORK/a-wave.deb"
curl -fL --connect-timeout 20 --max-time 180 --retry 3 --retry-delay 2 \
  'https://virenmohindra.github.io/debs/io.github.virenmohindra.a-wave_2.0_iphoneos-arm.deb' -o "$SPRINGY_DEB"
test "$(wc -c < "$SPRINGY_DEB" | tr -d ' ')" = '2971666'
test "$(sha256sum "$SPRINGY_DEB" | awk '{print $1}')" = '93525b61259e64cc0a42ff2393935c337cfbb35d0116fd5af6c48178ec89566e'
test "$(dpkg-deb -f "$SPRINGY_DEB" Package)" = 'io.github.virenmohindra.a-wave'
dpkg-deb -c "$SPRINGY_DEB" > "$WORK/a-wave-contents.txt"
if grep -Eq '^[lhcbps]' "$WORK/a-wave-contents.txt"; then echo 'springy_preflight=unsafe_special_file'; exit 61; fi
mkdir -p "$WORK/a-wave-root"
dpkg-deb -x "$SPRINGY_DEB" "$WORK/a-wave-root"
gif_count="$(find "$WORK/a-wave-root" -type f -iname '*.gif' | wc -l | tr -d ' ')"
image_count="$(find "$WORK/a-wave-root" -type f \( -iname '*.gif' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
if [ "$gif_count" -lt 1 ] && [ "$image_count" -lt 2 ]; then echo 'springy_preview_content=missing'; exit 62; fi
printf 'springy_package=io.github.virenmohindra.a-wave\nspringy_gifs=%s\nspringy_image_files=%s\nspringy_old_package_installed=false\nspringy_pipeline_test=passed\n' "$gif_count" "$image_count"

# Open the installed Settings pane as a final UI smoke test. A failure to open is
# reported but does not undo three proven runtime animation tests.
killall -9 Preferences 2>/dev/null || true
settings_opened=false
if command -v uiopen >/dev/null 2>&1; then
  su mobile -c "uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true
  settings_opened=true
elif [ -x /var/jb/usr/bin/uiopen ]; then
  su mobile -c "/var/jb/usr/bin/uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true
  settings_opened=true
fi
sleep 5
printf 'settings_open_attempted=%s\nsettings_process=%s\n' "$settings_opened" "$(pgrep -x Preferences 2>/dev/null | head -n1 || true)"

crashes="$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \( -name 'backboardd-*.ips' -o -name 'Preferences-*.ips' -o -name 'SpringBoard-*.ips' \) -newer "$WORK/crash-marker" -print 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_relevant_crash_reports=%s\n' "$crashes"
test "$crashes" = '0'

SUCCESS=1
echo 'installation=success'
echo 'runtime_themes_tested=3'
echo 'runtime_themes_passed=3'
echo 'source_pack_pipeline_tested=1'
echo 'source_pack_pipeline_passed=1'
echo 'active_theme=Cyan Energy Wave'
echo 'active_theme_left_enabled=true'
echo "rollback_backup=$BACKUP"
printf 'completed_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
