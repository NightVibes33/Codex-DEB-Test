#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

DEB_URL='https://sdmntprcentralus.oaiusercontent.com/files/00000000-12f8-81f5-b5bb-270943ba11d6/raw?se=2026-07-26T00%3A27%3A21Z&sp=r&sv=2026-02-06&sr=b&scid=1ee8f7b6-a22c-51ed-bbdf-11245dfbc5d2&skoid=2d2fbb03-9efb-4ad0-a91c-1db2f5a47997&sktid=a48cca56-e6da-484e-a814-9c849652bcb3&skt=2026-07-25T08%3A05%3A37Z&ske=2026-07-27T08%3A05%3A37Z&sks=b&skv=2026-02-06&sig=fYNDxG5gLfN2PIAIVIeaA2wJ4xGMWuOHpNxJMVIx5P4%3D'
EXPECTED_SHA256='182ad48790fb991f61e1afae14d26c831c232b7b5d3ec7c621726efc0b4d2c67'
WORK='/var/mobile/Library/Caches/Gif2AniRemoteInstall'
DEB="$WORK/com.nightvibes33.gif2ani_3.4.0_iphoneos-arm64.deb"
PREFS='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'

cleanup() {
  rm -rf "$WORK" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

printf '=== Gif2Ani remote install ===\n'
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true

mkdir -p "$WORK"
rm -f "$DEB"

if command -v curl >/dev/null 2>&1; then
  curl -fL --connect-timeout 25 --max-time 180 --retry 3 --retry-delay 2 "$DEB_URL" -o "$DEB"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$DEB" "$DEB_URL"
else
  echo 'install_error=no_http_downloader'
  exit 20
fi

[ -s "$DEB" ] || { echo 'install_error=empty_deb'; exit 21; }

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA256="$(sha256sum "$DEB" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA256="$(shasum -a 256 "$DEB" | awk '{print $1}')"
else
  echo 'install_error=no_sha256_tool'
  exit 22
fi
printf 'download_sha256=%s\n' "$ACTUAL_SHA256"
[ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] || { echo 'install_error=sha256_mismatch'; exit 23; }

PACKAGE="$(dpkg-deb -f "$DEB" Package 2>/dev/null || true)"
VERSION="$(dpkg-deb -f "$DEB" Version 2>/dev/null || true)"
ARCH="$(dpkg-deb -f "$DEB" Architecture 2>/dev/null || true)"
printf 'deb_package=%s\ndeb_version=%s\ndeb_architecture=%s\n' "$PACKAGE" "$VERSION" "$ARCH"
[ "$PACKAGE" = 'com.nightvibes33.gif2ani' ] || { echo 'install_error=wrong_package'; exit 24; }
[ "$VERSION" = '3.4.0' ] || { echo 'install_error=wrong_version'; exit 25; }
[ "$ARCH" = 'iphoneos-arm64' ] || { echo 'install_error=wrong_architecture'; exit 26; }

BACKBOARD_BEFORE="$(pgrep -x backboardd 2>/dev/null | head -n 1 || true)"
printf 'backboard_pid_before=%s\n' "$BACKBOARD_BEFORE"

# Fail closed before installation. The package must not activate until the user
# explicitly stages a theme and presses Apply and Respring in Settings.
mkdir -p "$(dirname "$PREFS")"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$PREFS" <<'PY'
import os, plistlib, sys
path=sys.argv[1]
data={}
try:
    with open(path,'rb') as f:
        loaded=plistlib.load(f)
        if isinstance(loaded,dict): data=loaded
except Exception:
    pass
data['isEnabled']=False
data['pendingReady']=False
with open(path+'.tmp','wb') as f: plistlib.dump(data,f,fmt=plistlib.FMT_BINARY)
os.replace(path+'.tmp',path)
PY
else
  defaults write com.nightvibes33.gif2ani isEnabled -bool false 2>/dev/null || true
fi
chown 501:501 "$PREFS" 2>/dev/null || true
chmod 0644 "$PREFS" 2>/dev/null || true

printf '%s\n' '=== Installing package ==='
dpkg -i "$DEB"

printf '%s\n' '=== Smoke test 1: package database ==='
INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani 2>/dev/null || true)"
printf 'installed_version=%s\n' "$INSTALLED_VERSION"
[ "$INSTALLED_VERSION" = '3.4.0' ] || { echo 'test1=failed'; exit 31; }
echo 'test1=passed'

printf '%s\n' '=== Smoke test 2: rootless files ==='
DYLIB='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib'
FILTER='/var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.plist'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Gif2AniPrefs'
ROOT_PLIST='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Root.plist'
for FILE in "$DYLIB" "$FILTER" "$BUNDLE" "$ROOT_PLIST"; do
  [ -s "$FILE" ] || { echo "missing_file=$FILE"; echo 'test2=failed'; exit 32; }
  printf 'present=%s\n' "$FILE"
done
echo 'test2=passed'

printf '%s\n' '=== Smoke test 3: fail-closed preference ==='
ENABLED='unknown'
if command -v python3 >/dev/null 2>&1; then
  ENABLED="$(python3 - "$PREFS" <<'PY'
import plistlib,sys
try:
    with open(sys.argv[1],'rb') as f: d=plistlib.load(f)
    print('true' if bool(d.get('isEnabled',False)) else 'false')
except Exception:
    print('unreadable')
PY
)"
fi
printf 'is_enabled=%s\n' "$ENABLED"
[ "$ENABLED" = 'false' ] || { echo 'test3=failed'; exit 33; }
echo 'test3=passed'

sleep 5
BACKBOARD_AFTER="$(pgrep -x backboardd 2>/dev/null | head -n 1 || true)"
printf '%s\n' '=== Smoke test 4: BackBoard stability ==='
printf 'backboard_pid_after=%s\n' "$BACKBOARD_AFTER"
[ -n "$BACKBOARD_BEFORE" ] && [ "$BACKBOARD_BEFORE" = "$BACKBOARD_AFTER" ] || { echo 'test4=failed'; exit 34; }
echo 'test4=passed'

printf '%s\n' '=== Result ==='
echo 'installation=success'
echo 'automatic_theme_activation=not_performed'
echo 'next_step=open Settings > Gif2Ani and preview a theme'
printf 'completed_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
