#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

ROOTLESS_SH=''
for candidate in /var/jb/usr/bin/sh /var/jb/bin/sh /usr/bin/sh; do
  if [ -x "$candidate" ]; then ROOTLESS_SH="$candidate"; break; fi
done
[ -n "$ROOTLESS_SH" ] || { echo 'launcher_error=no_executable_rootless_shell'; exit 120; }
printf 'rootless_shell=%s\n' "$ROOTLESS_SH"

WORK='/var/mobile/Library/Caches/Gif2Ani341RemoteInstall'
ZIP="$WORK/Gif2Ani-3.4.1-rootless-deb.zip"
DEB="$WORK/com.nightvibes33.gif2ani_3.4.1_iphoneos-arm64.deb"
SCRIPT="$WORK/gif2ani-341-runtime-retest.sh"
ARTIFACT_URL='https://sdmntprwestus2.oaiusercontent.com/files/00000000-e72c-81f8-8f8f-931b73a34419/raw?se=2026-07-26T01%3A44%3A05Z&sp=r&sv=2026-02-06&sr=b&scid=dbb233b0-8787-51e2-a49c-408909013e3c&skoid=2d2fbb03-9efb-4ad0-a91c-1db2f5a47997&sktid=a48cca56-e6da-484e-a814-9c849652bcb3&skt=2026-07-25T14%3A27%3A09Z&ske=2026-07-27T14%3A27%3A09Z&sks=b&skv=2026-02-06&sig=qWuT9n38DuGjshx6ZE4fV5BPMCOSNl4OJXNkVWQoMg0%3D'
EXPECTED_ZIP_SHA256='9c1f8635b8d9c6e127274f3b6c85c6d9bb8585d3eb08e31c43f59b0772c8846e'
EXPECTED_DEB_SHA256='54877fb227693bc6e5d6733cc77a5cba722479d5ee2c3f1806840d5b1415b982'
SCRIPT_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/main/remote/gif2ani-341-runtime-retest.sh'

rm -rf "$WORK"
mkdir -p "$WORK"

echo '=== Download verified green Gif2Ani 3.4.1 artifact ==='
curl -fL --connect-timeout 25 --max-time 240 --retry 4 --retry-delay 2 "$ARTIFACT_URL" -o "$ZIP"
test -s "$ZIP"
ZIP_SHA="$(sha256sum "$ZIP" | awk '{print $1}')"
printf 'artifact_zip_sha256=%s\n' "$ZIP_SHA"
test "$ZIP_SHA" = "$EXPECTED_ZIP_SHA256"

python3 - "$ZIP" "$WORK" <<'PY'
import os,sys,zipfile
archive,out=sys.argv[1:3]
with zipfile.ZipFile(archive) as z:
    names=z.namelist()
    debs=[n for n in names if n.endswith('.deb') and '/' not in n.strip('/')]
    if len(debs) != 1:
        raise SystemExit(f'expected one top-level deb, found {debs!r}')
    info=z.getinfo(debs[0])
    if info.file_size <= 0 or info.file_size > 5*1024*1024:
        raise SystemExit('unsafe deb size')
    target=os.path.join(out,'com.nightvibes33.gif2ani_3.4.1_iphoneos-arm64.deb')
    with z.open(info) as src, open(target+'.new','wb') as dst:
        while True:
            chunk=src.read(1024*1024)
            if not chunk: break
            dst.write(chunk)
    os.replace(target+'.new',target)
    print('artifact_deb_entry='+debs[0])
PY

test -s "$DEB"
DEB_SHA="$(sha256sum "$DEB" | awk '{print $1}')"
printf 'artifact_deb_sha256=%s\n' "$DEB_SHA"
test "$DEB_SHA" = "$EXPECTED_DEB_SHA256"
test "$(dpkg-deb -f "$DEB" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$DEB" Version)" = '3.4.1'
test "$(dpkg-deb -f "$DEB" Architecture)" = 'iphoneos-arm64'

echo '=== Install Gif2Ani 3.4.1 ==='
dpkg -i "$DEB"
INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)"
printf 'installed_version_after_dpkg=%s\n' "$INSTALLED_VERSION"
test "$INSTALLED_VERSION" = '3.4.1'
test -s /var/jb/Library/MobileSubstrate/DynamicLibraries/Gif2Ani.dylib
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Gif2AniPrefs
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/ThemeCatalog.json
test -s /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/OpenThemeCatalog.json

curl -fL --connect-timeout 20 --max-time 120 --retry 4 --retry-delay 2 "$SCRIPT_URL" -o "$SCRIPT"
test -s "$SCRIPT"
chmod 0700 "$SCRIPT"

echo 'install_phase=success'
echo 'runtime_test_phase=starting'
exec "$ROOTLESS_SH" "$SCRIPT"
