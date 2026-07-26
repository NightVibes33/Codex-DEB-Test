#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

printf '%s\n' '=== Repair Gif2Ani version shown in Settings ==='
printf 'started_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'identity='; id
printf 'package_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || echo absent

python3 <<'PY'
from pathlib import Path

roots = [Path('/var/jb/Library/PreferenceBundles'), Path('/Library/PreferenceBundles')]
matched = []
patched = []
for root in roots:
    if not root.exists():
        continue
    for bundle in root.glob('Gif2AniPrefs.bundle'):
        for name in ('Root.plist', 'Info.plist'):
            p = bundle / name
            if not p.is_file():
                continue
            data = p.read_bytes()
            old = data
            if name == 'Root.plist':
                data = data.replace(b'GIF2ANI 3.4.1', b'GIF2ANI 3.5.3')
            matched.append(str(p))
            if data != old:
                backup = p.with_name(p.name + '.pre-version-fix')
                if not backup.exists():
                    backup.write_bytes(old)
                p.write_bytes(data)
                patched.append(str(p))

print('matched_plists=' + str(len(matched)))
for p in matched:
    print('matched=' + p)
print('patched_plists=' + str(len(patched)))
for p in patched:
    print('patched=' + p)

rootless = Path('/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Root.plist')
assert rootless.is_file(), rootless
text = rootless.read_text(errors='replace')
print('rootless_has_353_label=' + str('GIF2ANI 3.5.3' in text).lower())
print('rootless_has_stale_341_label=' + str('GIF2ANI 3.4.1' in text).lower())
assert 'GIF2ANI 3.5.3' in text
assert 'GIF2ANI 3.4.1' not in text
PY

killall -9 Preferences 2>/dev/null || true
killall -9 cfprefsd 2>/dev/null || true
uicache -a >/dev/null 2>&1 || true
sync
sleep 3

printf 'package_version_after='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani
printf 'visible_label_after='; grep -o 'GIF2ANI [0-9.]*' /var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle/Root.plist | head -n 1

if command -v uiopen >/dev/null 2>&1; then
  uiopen 'prefs:root=Gif2Ani' >/dev/null 2>&1 || true
  echo 'gif2ani_settings_reopened=true'
fi

echo 'gif2ani_visible_version_fix=success'
