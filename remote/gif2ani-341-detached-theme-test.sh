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
OLD_BACKUP="$MEDIA/RemoteRuntimeRetestBackup"
BACKUP="$MEDIA/DetachedThemeTestBackup"
WORK='/var/mobile/Library/Caches/Gif2Ani341DetachedThemeTest'
RESTORED=0
PASSED=0

sha_file() {
  if [ -f "$1" ]; then sha256sum "$1" | awk '{print $1}'; else printf 'MISSING'; fi
}

restore_from_backup() {
  backup="$1"
  [ -d "$backup" ] || return 0
  if [ -f "$backup/had-active" ] && [ -f "$backup/Active.gif" ]; then
    cp -p "$backup/Active.gif" "$ACTIVE"
  else
    rm -f "$ACTIVE"
  fi
  if [ -f "$backup/had-prefs" ] && [ -f "$backup/preferences.plist" ]; then
    cp -p "$backup/preferences.plist" "$PREFS"
  else
    rm -f "$PREFS"
  fi
  if [ -f "$backup/had-runtime" ] && [ -f "$backup/runtime-status.plist" ]; then
    cp -p "$backup/runtime-status.plist" "$RUNTIME"
  else
    rm -f "$RUNTIME"
  fi
  rm -f "$SENTINEL" "$REJECTED"
  chown 501:501 "$ACTIVE" "$PREFS" "$RUNTIME" 2>/dev/null || true
  chmod 0644 "$ACTIVE" "$PREFS" "$RUNTIME" 2>/dev/null || true
}

restart_backboard() {
  if killall -9 backboardd 2>/dev/null; then
    echo 'restart_method=killall'
  elif launchctl kickstart -k user/501/com.apple.backboardd 2>/dev/null; then
    echo 'restart_method=launchctl-user'
  elif launchctl kickstart -k system/com.apple.backboardd 2>/dev/null; then
    echo 'restart_method=launchctl-system'
  elif [ -x /var/jb/usr/bin/sbreload ]; then
    /var/jb/usr/bin/sbreload 2>/dev/null || true
    echo 'restart_method=sbreload'
  else
    echo 'test_error=no_backboard_restart_method'
    return 1
  fi
}

restore_original() {
  [ "$RESTORED" -eq 0 ] || return 0
  echo 'restore_original=starting'
  restore_from_backup "$BACKUP"
  restart_backboard || true
  sleep 8
  RESTORED=1
  echo 'restore_original=complete'
}

finish() {
  code=$?
  trap - EXIT INT TERM HUP
  restore_original || true
  rm -rf "$WORK" 2>/dev/null || true
  if [ "$PASSED" -eq 1 ]; then exit 0; fi
  exit "$code"
}
trap finish EXIT INT TERM HUP

mkdir -p "$MEDIA" "$WORK"

# Recover the user's real state if a previous foreground test was interrupted by a respring.
if [ -d "$OLD_BACKUP" ]; then
  echo 'interrupted_test_recovery=starting'
  restore_from_backup "$OLD_BACKUP"
  echo 'interrupted_test_recovery=complete'
fi

rm -rf "$BACKUP"
mkdir -p "$BACKUP"
if [ -f "$ACTIVE" ]; then touch "$BACKUP/had-active"; cp -p "$ACTIVE" "$BACKUP/Active.gif"; fi
if [ -f "$PREFS" ]; then touch "$BACKUP/had-prefs"; cp -p "$PREFS" "$BACKUP/preferences.plist"; fi
if [ -f "$RUNTIME" ]; then touch "$BACKUP/had-runtime"; cp -p "$RUNTIME" "$BACKUP/runtime-status.plist"; fi
ORIGINAL_ACTIVE_SHA="$(sha_file "$ACTIVE")"
ORIGINAL_PREFS_SHA="$(sha_file "$PREFS")"

printf '%s\n' '=== Gif2Ani 3.4.1 detached three-theme proof ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true
INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani 2>/dev/null || true)"
printf 'installed_version=%s\n' "$INSTALLED_VERSION"
test "$INSTALLED_VERSION" = '3.4.1'
test -s /var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Gif2AniPrefs
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/ThemeCatalog.json
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/OpenThemeCatalog.json
printf 'original_active_sha256=%s\n' "$ORIGINAL_ACTIVE_SHA"
printf 'original_preferences_sha256=%s\n' "$ORIGINAL_PREFS_SHA"
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
print('prefs_isEnabled=true')
print('prefs_theme='+name)
PY
  chown 501:501 "$PREFS"
  chmod 0644 "$PREFS"
}

runtime_event() {
  python3 - "$RUNTIME" <<'PY'
import plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: print(plistlib.load(f).get('event','missing'))
except Exception: print('unreadable')
PY
}

print_runtime() {
  python3 - "$RUNTIME" <<'PY'
import json,plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: data=plistlib.load(f)
    print('runtime_plist='+json.dumps(data,sort_keys=True,default=str))
except Exception as e:
    print('runtime_plist_error='+repr(e))
PY
}

wait_for_runtime() {
  i=0
  while [ "$i" -lt 40 ]; do
    event="$(runtime_event)"
    printf 'runtime_poll_%s=%s\n' "$i" "$event"
    case "$event" in
      custom-animation-stable) return 0 ;;
      gif-auto-disabled|decode-exception|no-active-gif) return 1 ;;
    esac
    if [ -e "$REJECTED" ]; then echo 'runtime_failure=rejected_gif_created'; return 1; fi
    i=$((i+1))
    sleep 1
  done
  echo 'runtime_failure=timeout'
  return 1
}

run_theme() {
  name="$1"; file="$2"; expected_bytes="$3"; expected_sha="$4"
  target="$WORK/$file"
  echo "=== theme_begin=$name ==="
  curl -fL --connect-timeout 20 --max-time 120 --retry 4 --retry-delay 2 "$CATALOG_BASE/$file" -o "$target"
  actual_bytes="$(wc -c < "$target" | tr -d ' ')"
  actual_sha="$(sha256sum "$target" | awk '{print $1}')"
  signature="$(dd if="$target" bs=1 count=6 2>/dev/null || true)"
  printf 'actual_bytes=%s\nexpected_bytes=%s\nactual_sha256=%s\nexpected_sha256=%s\ngif_signature=%s\n' "$actual_bytes" "$expected_bytes" "$actual_sha" "$expected_sha" "$signature"
  test "$actual_bytes" = "$expected_bytes"
  test "$actual_sha" = "$expected_sha"
  case "$signature" in GIF87a|GIF89a) ;; *) return 71 ;; esac

  cp "$target" "$ACTIVE.new"
  chown 501:501 "$ACTIVE.new"
  chmod 0644 "$ACTIVE.new"
  mv -f "$ACTIVE.new" "$ACTIVE"
  write_test_preferences "$name"
  rm -f "$RUNTIME" "$REJECTED" "$SENTINEL"
  sync 2>/dev/null || true
  restart_backboard
  wait_for_runtime
  print_runtime
  test "$(runtime_event)" = 'custom-animation-stable'
  test ! -e "$REJECTED"
  test ! -e "$SENTINEL"
  echo "theme_test=$name:passed"
}

run_theme 'Cyan Pulse Rings' 'cyan-pulse-rings.gif' '130275' '1975aa569fb5ee0002856a7cff3b60bbcde04126514386fbd52b89d9f5349a46'
run_theme 'Cyan Halo Spinner' 'cyan-halo-spinner.gif' '49717' 'f0447aeece060d4e0ae563ad1e18c7055e8055a976d70b61c8d69f04db4c14cb'
run_theme 'Cyan Energy Wave' 'cyan-energy-wave.gif' '52155' '74d773db3f6b8f98daad1234266f3b594698cca200a0858f3c39494154b2c337'

# The original Springy host changed A Wave without changing its package version.
# The bundled pinned snapshot must reject those changed bytes rather than silently trusting them.
echo '=== springy_integrity_rejection_test ==='
SPRINGY="$WORK/a-wave.deb"
curl -fL --connect-timeout 20 --max-time 180 --retry 4 --retry-delay 2 'https://virenmohindra.github.io/debs/io.github.virenmohindra.a-wave_2.0_iphoneos-arm.deb' -o "$SPRINGY"
SPRINGY_BYTES="$(wc -c < "$SPRINGY" | tr -d ' ')"
SPRINGY_SHA="$(sha256sum "$SPRINGY" | awk '{print $1}')"
SPRINGY_PACKAGE="$(dpkg-deb -f "$SPRINGY" Package 2>/dev/null || true)"
printf 'springy_live_bytes=%s\nspringy_live_sha256=%s\nspringy_package=%s\n' "$SPRINGY_BYTES" "$SPRINGY_SHA" "$SPRINGY_PACKAGE"
test "$SPRINGY_PACKAGE" = 'io.github.virenmohindra.a-wave'
if [ "$SPRINGY_BYTES" != '2971666' ] || [ "$SPRINGY_SHA" != '93525b61259e64cc0a42ff2393935c337cfbb35d0116fd5af6c48178ec89566e' ]; then
  echo 'springy_changed_upstream_safely_rejected=true'
else
  echo 'springy_snapshot_still_matches=true'
fi

CRASHES="$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \( -name 'backboardd-*.ips' -o -name 'Preferences-*.ips' -o -name 'SpringBoard-*.ips' \) -newer "$WORK/crash-marker" -print 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_relevant_crash_reports=%s\n' "$CRASHES"
test "$CRASHES" = '0'

restore_original
RESTORED_ACTIVE_SHA="$(sha_file "$ACTIVE")"
RESTORED_PREFS_SHA="$(sha_file "$PREFS")"
printf 'restored_active_sha256=%s\n' "$RESTORED_ACTIVE_SHA"
printf 'restored_preferences_sha256=%s\n' "$RESTORED_PREFS_SHA"
test "$RESTORED_ACTIVE_SHA" = "$ORIGINAL_ACTIVE_SHA"
test "$RESTORED_PREFS_SHA" = "$ORIGINAL_PREFS_SHA"

PASSED=1
echo 'detached_theme_test=success'
echo 'runtime_themes_passed=3'
echo 'active_state_restored=true'
printf 'completed_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
