#!/bin/sh
set -eu

export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

media='/var/mobile/Library/Application Support/Gif2Ani'
prefs='/var/mobile/Library/Preferences/com.nightvibes33.gif2ani.plist'
active="$media/Active.gif"
pending="$media/Pending.gif"
pending_meta="$media/pending-metadata.plist"
runtime="$media/runtime-status.plist"
deb='/var/mobile/Media/Gif2Ani-3.4.1-final.deb'
work='/var/mobile/Library/Caches/Gif2Ani341Proof'
marker="$work/crash-marker"
prefs_snapshot="$work/preferences-before.plist"

rm -rf "$work"
mkdir -p "$work"
touch "$marker"

sha_file() {
  target="$1"
  if [ -f "$target" ]; then
    sha256sum "$target" | awk '{print $1}'
  else
    printf 'MISSING'
  fi
}

semantic_plist_equal() {
  before="$1"
  after="$2"
  python3 - "$before" "$after" <<'PY'
import plistlib,sys
from pathlib import Path

def load(path):
    p=Path(path)
    if not p.exists():
        return ('missing',None)
    with p.open('rb') as f:
        return ('present',plistlib.load(f))

assert load(sys.argv[1]) == load(sys.argv[2])
PY
}

if [ -f "$prefs" ]; then
  cp -p "$prefs" "$prefs_snapshot"
else
  rm -f "$prefs_snapshot"
fi

active_before=$(sha_file "$active")
prefs_before=$(sha_file "$prefs")
pending_before=$(sha_file "$pending")
pending_meta_before=$(sha_file "$pending_meta")
runtime_before=$(sha_file "$runtime")
backboard_before=$(pgrep -x backboardd 2>/dev/null | head -n1 || true)

echo "active_before=$active_before"
echo "prefs_before=$prefs_before"
echo "pending_before=$pending_before"
echo "pending_metadata_before=$pending_meta_before"
echo "runtime_before=$runtime_before"
echo "backboard_before=$backboard_before"

test -s "$deb"
test "$(dpkg-deb -f "$deb" Package)" = 'com.nightvibes33.gif2ani'
test "$(dpkg-deb -f "$deb" Version)" = '3.4.1'
test "$(dpkg-deb -f "$deb" Architecture)" = 'iphoneos-arm64'

dpkg -i "$deb"
test "$(dpkg-query -W -f='${Version}' com.nightvibes33.gif2ani)" = '3.4.1'

bundle='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'
test -s "$bundle/Gif2AniPrefs"
test -f "$bundle/Root.plist"
test -f "$bundle/ThemeCatalog.json"
test -f "$bundle/OpenThemeCatalog.json"
grep -Fq 'GIF2ANI 3.4.1' "$bundle/Root.plist"
grep -Fq '114-THEME ANIMATION GALLERY' "$bundle/Root.plist"

python3 - "$bundle/ThemeCatalog.json" "$bundle/OpenThemeCatalog.json" <<'PY'
import json,sys
cc0=json.load(open(sys.argv[1]))
original=json.load(open(sys.argv[2]))
assert cc0['version']==1
assert cc0['count']==len(cc0['themes'])==54
assert original['version']==1
assert original['count']==len(original['themes'])==48
assert original['sourceRepository']=='VirenMohindra/CydiaRepo'
assert original['sourceLicense']=='MIT'
assert len({item['package'] for item in original['themes']})==48
print('installed_cc0_manifest=54')
print('installed_original_springy_manifest=48')
print('installed_downloadable_total=102')
print('installed_first_class_total=114')
PY

cc0_url='https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/b5d5eda04359409865772038895e660d709deb18/gif2ani-themes/v1/cyan-pulse-rings.gif'
cc0_file="$work/cyan-pulse-rings.gif"
curl -fsSL --retry 3 --connect-timeout 20 --max-time 120 "$cc0_url" -o "$cc0_file"
test "$(wc -c < "$cc0_file" | tr -d ' ')" = '130275'
test "$(sha256sum "$cc0_file" | awk '{print $1}')" = '1975aa569fb5ee0002856a7cff3b60bbcde04126514386fbd52b89d9f5349a46'
test "$(dd if="$cc0_file" bs=6 count=1 2>/dev/null)" = 'GIF89a'
echo 'cc0_sample_download=verified'

springy_url='https://virenmohindra.github.io/debs/io.github.virenmohindra.a-wave_2.0_iphoneos-arm.deb'
springy_deb="$work/a-wave.deb"
curl -fsSL --retry 3 --connect-timeout 20 --max-time 180 "$springy_url" -o "$springy_deb"
test "$(wc -c < "$springy_deb" | tr -d ' ')" = '2971666'
test "$(sha256sum "$springy_deb" | awk '{print $1}')" = '93525b61259e64cc0a42ff2393935c337cfbb35d0116fd5af6c48178ec89566e'
test "$(dpkg-deb -f "$springy_deb" Package)" = 'io.github.virenmohindra.a-wave'

springy_listing="$work/a-wave-contents.txt"
dpkg-deb -c "$springy_deb" > "$springy_listing"
if grep -Eq '^[lhcbps]' "$springy_listing"; then
  echo 'springy_archive_unsafe_special_file=true'
  exit 41
fi
if grep -Eq '(^|[[:space:]])(\.\./|/[^.])' "$springy_listing"; then
  echo 'springy_archive_unsafe_path=true'
  exit 42
fi

mkdir -p "$work/a-wave-root"
dpkg-deb -x "$springy_deb" "$work/a-wave-root"
media_count=$(find "$work/a-wave-root" -type f \( -iname '*.gif' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | wc -l | tr -d ' ')
test "$media_count" -ge 2
echo "springy_sample_media_files=$media_count"
echo 'springy_sample_download=verified'
echo 'springy_deb_installed=false'

killall -9 Preferences 2>/dev/null || true
settings_open_attempted=false
if command -v uiopen >/dev/null 2>&1; then
  su mobile -c "uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true
  settings_open_attempted=true
elif [ -x /var/jb/usr/bin/uiopen ]; then
  su mobile -c "/var/jb/usr/bin/uiopen 'prefs:root=Gif2Ani'" >/dev/null 2>&1 || true
  settings_open_attempted=true
fi
sleep 6
preferences_pid=$(pgrep -x Preferences 2>/dev/null | head -n1 || true)
echo "settings_open_attempted=$settings_open_attempted"
echo "preferences_pid=$preferences_pid"

active_after=$(sha_file "$active")
prefs_after=$(sha_file "$prefs")
pending_after=$(sha_file "$pending")
pending_meta_after=$(sha_file "$pending_meta")
runtime_after=$(sha_file "$runtime")
backboard_after=$(pgrep -x backboardd 2>/dev/null | head -n1 || true)

test "$active_before" = "$active_after"
test "$pending_before" = "$pending_after"
test "$pending_meta_before" = "$pending_meta_after"
test "$runtime_before" = "$runtime_after"
test -n "$backboard_before"
test "$backboard_before" = "$backboard_after"

if [ -f "$prefs_snapshot" ]; then
  test -f "$prefs"
  semantic_plist_equal "$prefs_snapshot" "$prefs"
else
  test ! -f "$prefs"
fi

crashes=$(find /var/mobile/Library/Logs/CrashReporter -maxdepth 1 -type f \
  \( -name 'backboardd-*.ips' -o -name 'SpringBoard-*.ips' -o -name 'Preferences-*.ips' \) \
  -newer "$marker" -print 2>/dev/null | wc -l | tr -d ' ')
test "$crashes" = '0'

echo 'installed_version=3.4.1'
echo 'active_gif_preserved=true'
echo 'preferences_semantically_preserved=true'
echo "preferences_raw_hash_before=$prefs_before"
echo "preferences_raw_hash_after=$prefs_after"
echo 'pending_state_preserved=true'
echo 'runtime_status_preserved=true'
echo 'backboard_pid_preserved=true'
echo "new_crash_reports=$crashes"
echo 'gif2ani_341_device_proof=success'

rm -rf "$work"
