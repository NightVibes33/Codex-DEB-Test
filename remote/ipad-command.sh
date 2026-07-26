#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

MEDIA='/var/mobile/Library/Application Support/Gif2Ani'
CATALOG="$MEDIA/Catalog"
OPEN="$MEDIA/OpenThemeLibrary"
CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
MARK='/tmp/gif2ani-source-download-crash-marker'
WORK='/tmp/gif2ani-source-download-test'

CC0_URL='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/b5d5eda04359409865772038895e660d709deb18/gif2ani-themes/v1/cyan-pulse-rings.gif'
CC0_SHA='1975aa569fb5ee0002856a7cff3b60bbcde04126514386fbd52b89d9f5349a46'
CC0_BYTES='130275'
CC0_DEST="$CATALOG/cyan-pulse-rings.gif"

SPRINGY_URL='https://virenmohindra.github.io/debs/io.github.virenmohindra.a-wave_2.0_iphoneos-arm.deb'
SPRINGY_SHA='853d01e5a41092561d47dc6ccfc87b9e547dd926b7ba1daa9980fe148e276279'
SPRINGY_BYTES='2971658'
SPRINGY_PACKAGE='io.github.virenmohindra.a-wave'

printf '%s\n' '=== Gif2Ani source-backed download tests ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.5.0'

rm -rf "$WORK"; mkdir -p "$WORK" "$CATALOG" "$OPEN"
rm -f "$MARK"; : > "$MARK"
trap 'rm -rf "$WORK"; rm -f "$MARK"' EXIT INT TERM

fetch() {
  src="$1"; dst="$2"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 --max-time 120 -o "$dst" "$src"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$dst" "$src"
  else
    echo 'download_tool=missing' >&2; exit 20
  fi
}

CC0_TMP="$WORK/cyan-pulse-rings.gif.download"
fetch "$CC0_URL" "$CC0_TMP"
ACTUAL_CC0_BYTES="$(wc -c < "$CC0_TMP" | tr -d ' ')"
ACTUAL_CC0_SHA="$(sha256sum "$CC0_TMP" | awk '{print $1}')"
printf 'cc0_download_bytes=%s\n' "$ACTUAL_CC0_BYTES"
printf 'cc0_download_sha256=%s\n' "$ACTUAL_CC0_SHA"
test "$ACTUAL_CC0_BYTES" = "$CC0_BYTES"
test "$ACTUAL_CC0_SHA" = "$CC0_SHA"
python3 - "$CC0_TMP" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1]); data=p.read_bytes()
assert data[:6] in (b'GIF87a', b'GIF89a')
assert data.endswith(b';')
print('cc0_gif_structure=passed')
PY
rm -f "$CC0_DEST.new"
cp "$CC0_TMP" "$CC0_DEST.new"
chmod 0644 "$CC0_DEST.new"
chown 501:501 "$CC0_DEST.new" 2>/dev/null || true
mv -f "$CC0_DEST.new" "$CC0_DEST"
test "$(sha256sum "$CC0_DEST" | awk '{print $1}')" = "$CC0_SHA"
echo 'cc0_cache_install=success'

SPRINGY_DEB="$WORK/a-wave.deb"
SPRINGY_ROOT="$WORK/a-wave-root"
fetch "$SPRINGY_URL" "$SPRINGY_DEB"
ACTUAL_SPRINGY_BYTES="$(wc -c < "$SPRINGY_DEB" | tr -d ' ')"
ACTUAL_SPRINGY_SHA="$(sha256sum "$SPRINGY_DEB" | awk '{print $1}')"
printf 'springy_download_bytes=%s\n' "$ACTUAL_SPRINGY_BYTES"
printf 'springy_download_sha256=%s\n' "$ACTUAL_SPRINGY_SHA"
test "$ACTUAL_SPRINGY_BYTES" = "$SPRINGY_BYTES"
test "$ACTUAL_SPRINGY_SHA" = "$SPRINGY_SHA"
test "$(dpkg-deb -f "$SPRINGY_DEB" Package | tr -d '\r\n')" = "$SPRINGY_PACKAGE"
printf 'springy_package_version='; dpkg-deb -f "$SPRINGY_DEB" Version | tr -d '\r'; echo

# Reject traversal and links before extraction, matching Gif2Ani's safe-import contract.
dpkg-deb -c "$SPRINGY_DEB" > "$WORK/deb-listing.txt"
python3 - "$WORK/deb-listing.txt" <<'PY'
import pathlib, re, sys
lines=pathlib.Path(sys.argv[1]).read_text(errors='replace').splitlines()
entries=0
for line in lines:
    if not line.strip(): continue
    kind=line[0]
    assert kind not in 'lhcbps', line
    m=re.search(r' (\./.*)$', line)
    if not m: continue
    path=m.group(1).split(' -> ',1)[0]
    parts=path.replace('\\','/').split('/')
    assert '..' not in parts and not path.startswith('/'), path
    entries+=1
assert 0 < entries <= 5000, entries
print('springy_archive_entries='+str(entries))
print('springy_archive_preflight=passed')
PY
mkdir -p "$SPRINGY_ROOT"
dpkg-deb -x "$SPRINGY_DEB" "$SPRINGY_ROOT"
python3 - "$SPRINGY_ROOT" <<'PY'
import pathlib, sys
root=pathlib.Path(sys.argv[1]).resolve()
files=[]; total=0; images=[]
for p in root.rglob('*'):
    assert not p.is_symlink(), p
    if p.is_file():
        files.append(p); total += p.stat().st_size
        if p.suffix.lower() in {'.png','.jpg','.jpeg','.gif','.webp'}: images.append(p)
assert 0 < len(files) <= 5000
assert total <= 150*1024*1024
assert len(images) >= 2
print('springy_extracted_files='+str(len(files)))
print('springy_extracted_bytes='+str(total))
print('springy_animation_media_files='+str(len(images)))
print('springy_extracted_tree_validation=passed')
PY
# Prove the legacy package was inspected only, never installed.
if dpkg-query -W -f='${Status}' "$SPRINGY_PACKAGE" 2>/dev/null | grep -Fq 'install ok installed'; then
  echo 'springy_legacy_package_installed=true' >&2
  exit 31
fi
echo 'springy_legacy_package_installed=false'
echo 'springy_original_deb_test=success'

# Existing normalized cache, when present, must still match the pinned upstream SHA.
if [ -f "$OPEN/$SPRINGY_PACKAGE/metadata.plist" ]; then
  python3 - "$OPEN/$SPRINGY_PACKAGE/metadata.plist" "$SPRINGY_SHA" <<'PY'
import plistlib, sys
with open(sys.argv[1],'rb') as f: m=plistlib.load(f)
assert m.get('package') == 'io.github.virenmohindra.a-wave'
assert m.get('sha256') == sys.argv[2]
assert m.get('kind') in ('gif','frames')
assert m.get('relativePath')
print('springy_normalized_cache=valid')
PY
else
  echo 'springy_normalized_cache=not_present_download_path_still_verified'
fi

killall -9 Preferences 2>/dev/null || true
sleep 1
if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  sleep 2
  uiopen 'prefs:root=Gif2Ani&G2ThemeGallery' >/dev/null 2>&1 || true
  sleep 5
  echo 'settings_gallery_links_opened=true'
fi
NEW_CRASHES="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -newer "$MARK" 2>/dev/null | wc -l | tr -d ' ')"
printf 'new_preferences_crashes=%s\n' "$NEW_CRASHES"
test "$NEW_CRASHES" = '0'

echo 'gif2ani_cc0_download_test=success'
echo 'gif2ani_springy_download_test=success'
echo 'gif2ani_source_backed_tests=success'
