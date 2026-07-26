#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

CATALOG_BASE='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/b5d5eda04359409865772038895e660d709deb18/gif2ani-themes/v1'
MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
ACTIVE="$MEDIA/Active.gif"
RUNTIME="$MEDIA/runtime-status.plist"
REJECTED="$MEDIA/Rejected.gif"
SENTINEL="$MEDIA/load-in-progress"
WORK='/var/mobile/Library/Caches/Gif2Ani341RuntimeRetest'
BACKUP="$MEDIA/RemoteRuntimeRetestBackup"
SUCCESS=0

restore_state() {
  echo 'rollback=starting'
  if [ -f "$BACKUP/had-active" ]; then cp -p "$BACKUP/Active.gif" "$ACTIVE"; else rm -f "$ACTIVE"; fi
  if [ -f "$BACKUP/had-prefs" ]; then cp -p "$BACKUP/preferences.plist" "$PREFS"; else rm -f "$PREFS"; fi
  rm -f "$SENTINEL" "$REJECTED"
  chown 501:501 "$ACTIVE" "$PREFS" 2>/dev/null || true
  chmod 0644 "$ACTIVE" "$PREFS" 2>/dev/null || true
  killall -9 backboardd 2>/dev/null || true
  sleep 5
  echo 'rollback=complete'
}

finish() {
  code=$?
  trap - EXIT INT TERM
  if [ "$code" -ne 0 ] && [ "$SUCCESS" -ne 1 ]; then restore_state || true; fi
  rm -rf "$WORK" 2>/dev/null || true
  exit "$code"
}
trap finish EXIT INT TERM

mkdir -p "$WORK" "$MEDIA"
rm -rf "$BACKUP"
mkdir -p "$BACKUP"
if [ -f "$ACTIVE" ]; then touch "$BACKUP/had-active"; cp -p "$ACTIVE" "$BACKUP/Active.gif"; fi
if [ -f "$PREFS" ]; then touch "$BACKUP/had-prefs"; cp -p "$PREFS" "$BACKUP/preferences.plist"; fi

echo '=== Gif2Ani 3.4.1 verbose runtime retest ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani 2>/dev/null || true)"
printf 'installed_version=%s\n' "$INSTALLED_VERSION"
test "$INSTALLED_VERSION" = '3.4.1'
test -s /var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Gif2AniPrefs
printf 'original_active_sha256=%s\n' "$(sha256sum "$ACTIVE" 2>/dev/null | awk '{print $1}' || printf MISSING)"
printf 'rollback_backup=%s\n' "$BACKUP"
touch "$WORK/crash-marker"

write_test_preferences() {
  name="$1"
  python3 - "$PREFS" "$name" <<'PY'
import os,plistlib,sys
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
with open(path+'.new','wb') as f: plistlib.dump(data,f,fmt=plistlib.FMT_BINARY)
os.replace(path+'.new',path)
print('prefs_isEnabled='+str(data['isEnabled']).lower())
print('prefs_theme='+name)
PY
  chown 501:501 "$PREFS"
  chmod 0644 "$PREFS"
}

wait_new_backboard() {
  old="$1"
  i=0
  while [ "$i" -lt 45 ]; do
    current="$(pgrep -x backboardd 2>/dev/null | head -n1 || true)"
    if [ -n "$current" ] && [ "$current" != "$old" ]; then printf '%s' "$current"; return 0; fi
    i=$((i+1))
    sleep 1
  done
  return 1
}

print_runtime_status() {
  python3 - "$RUNTIME" <<'PY'
import json,plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: data=plistlib.load(f)
    print('runtime_plist='+json.dumps(data,sort_keys=True,default=str))
    print('runtime_event='+str(data.get('event','missing')))
except Exception as e:
    print('runtime_plist_error='+repr(e))
    print('runtime_event=unreadable')
PY
}

run_theme_test() {
  name="$1"; file="$2"; expected_bytes="$3"; expected_sha="$4"
  target="$WORK/$file"
  echo "=== theme_begin=$name ==="
  curl -fL --connect-timeout 20 --max-time 120 --retry 3 --retry-delay 2 "$CATALOG_BASE/$file" -o "$target"
  actual_bytes="$(wc -c < "$target" | tr -d ' ')"
  actual_sha="$(sha256sum "$target" | awk '{print $1}')"
  signature="$(dd if="$target" bs=1 count=6 2>/dev/null || true)"
  printf 'download_file=%s\nactual_bytes=%s\nexpected_bytes=%s\nactual_sha256=%s\nexpected_sha256=%s\ngif_signature=%s\n' "$file" "$actual_bytes" "$expected_bytes" "$actual_sha" "$expected_sha" "$signature"
  test "$actual_bytes" = "$expected_bytes"
  test "$actual_sha" = "$expected_sha"
  case "$signature" in GIF87a|GIF89a) ;; *) echo 'theme_failure=invalid_gif_signature'; return 71 ;; esac

  cp "$target" "$ACTIVE.new"
  chown 501:501 "$ACTIVE.new"
  chmod 0644 "$ACTIVE.new"
  mv -f "$ACTIVE.new" "$ACTIVE"
  printf 'active_sha256=%s\n' "$(sha256sum "$ACTIVE" | awk '{print $1}')"
  test "$(sha256sum "$ACTIVE" | awk '{print $1}')" = "$expected_sha"

  write_test_preferences "$name"
  rm -f "$RUNTIME" "$REJECTED" "$SENTINEL"
  sync 2>/dev/null || true
  old_pid="$(pgrep -x backboardd 2>/dev/null | head -n1 || true)"
  printf 'backboard_pid_before=%s\n' "$old_pid"
  test -n "$old_pid"
  killall -9 backboardd
  new_pid="$(wait_new_backboard "$old_pid")"
  printf 'backboard_pid_after=%s\n' "$new_pid"
  test -n "$new_pid"
  sleep 10
  print_runtime_status
  event="$(python3 - "$RUNTIME" <<'PY'
import plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: print(plistlib.load(f).get('event','missing'))
except Exception: print('unreadable')
PY
)"
  test "$event" = 'custom-animation-stable'
  test ! -e "$REJECTED"
  test ! -e "$SENTINEL"
  printf 'theme_test=%s:passed\n' "$name"
}

run_theme_test 'Cyan Pulse Rings' 'cyan-pulse-rings.gif' '130275' '1975aa569fb5ee0002856a7cff3b60bbcde04126514386fbd52b89d9f5349a46'
run_theme_test 'Cyan Halo Spinner' 'cyan-halo-spinner.gif' '49717' 'f0447aeece060d4e0ae563ad1e18c7055e8055a976d70b61c8d69f04db4c14cb'
run_theme_test 'Cyan Energy Wave' 'cyan-energy-wave.gif' '52155' '74d773db3f6b8f98daad1234266f3b594698cca200a0858f3c39494154b2c337'

echo '=== original_springy_pack_test ==='
SPRINGY="$WORK/a-wave.deb"
curl -fL --connect-timeout 20 --max-time 180 --retry 3 --retry-delay 2 'https://virenmohindra.github.io/debs/io.github.virenmohindra.a-wave_2.0_iphoneos-arm.deb' -o "$SPRINGY"
springy_bytes="$(wc -c < "$SPRINGY" | tr -d ' ')"
springy_sha="$(sha256sum "$SPRINGY" | awk '{print $1}')"
springy_package="$(dpkg-deb -f "$SPRINGY" Package)"
printf 'springy_bytes=%s\nspringy_sha256=%s\nspringy_package=%s\n' "$springy_bytes" "$springy_sha" "$springy_package"
test "$springy_bytes" = '2971666'
test "$springy_sha" = '93525b61259e64cc0a42ff2393935c337cfbb35d0116fd5af6c48178ec89566e'
test "$springy_package" = 'io.github.virenmohindra.a-wave'
dpkg-deb -c "$SPRINGY" > "$WORK/a-wave-listing.txt"
if grep -Eq '^[lhcbps]' "$WORK/a-wave-listing.txt"; then echo 'springy_failure=special_file'; exit 81; fi
mkdir -p "$WORK/a-wave-root"
dpkg-deb -x "$SPRINGY" "$WORK/a-wave-root"
gifs="$(find "$WORK/a-wave-root" -type f -iname '*.gif' | wc -l | tr -d ' ')"
images="$(find "$WORK/a-wave-root" -type f \( -iname '*.gif' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
printf 'springy_gif_files=%s\nspringy_image_files=%s\nspringy_old_package_installed=false\n' "$gifs" "$images"
if [ "$gifs" -lt 1 ] && [ "$images" -lt 2 ]; then echo 'springy_failure=no_previewable_animation'; exit 82; fi
echo 'springy_pipeline_test=passed'

crashes="$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \( -name 'backboardd-*.ips' -o -name 'Preferences-*.ips' -o -name 'SpringBoard-*.ips' \) -newer "$WORK/crash-marker" -print 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_relevant_crash_reports=%s\n' "$crashes"
test "$crashes" = '0'

killall -9 Preferences 2>/dev/null || true
if command -v uiopen >/dev/null 2>&1; then su mobile -c "uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true; fi
sleep 4
printf 'preferences_pid=%s\n' "$(pgrep -x Preferences 2>/dev/null | head -n1 || true)"

SUCCESS=1
echo 'runtime_retest=success'
echo 'runtime_themes_passed=3'
echo 'springy_pipeline_passed=1'
echo 'active_theme=Cyan Energy Wave'
echo 'active_theme_left_enabled=true'
echo "rollback_backup=$BACKUP"
printf 'completed_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
