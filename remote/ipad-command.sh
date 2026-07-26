#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

CRASH_DIR='/var/mobile/Library/Logs/CrashReporter'
BUNDLE='/var/jb/Library/PreferenceBundles/Gif2AniPrefs.bundle'

echo '=== Gif2Ani Settings compact crash summary ==='
printf 'collected_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'model='; sysctl -n hw.model 2>/dev/null || true
printf 'installed_version='; dpkg-query -W -f='${Version}\n' com.nightvibes33.gif2ani 2>/dev/null || true
printf 'bundle_binary='; file "$BUNDLE/Gif2AniPrefs" 2>/dev/null || true
printf 'bundle_uuid='; dwarfdump --uuid "$BUNDLE/Gif2AniPrefs" 2>/dev/null || true

NEWEST="$(find "$CRASH_DIR" -maxdepth 1 -type f \( -name 'Preferences-*.ips' -o -name 'Preferences_*.ips' -o -name 'Preferences*.ips' \) -print 2>/dev/null | while IFS= read -r f; do stat -f '%m|%N' "$f" 2>/dev/null || stat -c '%Y|%n' "$f" 2>/dev/null || true; done | sort -t '|' -k1,1nr | head -n 1 | cut -d'|' -f2-)"

if [ -z "$NEWEST" ] || [ ! -f "$NEWEST" ]; then
  echo 'newest_preferences_crash=missing'
  exit 2
fi

printf 'newest_preferences_crash=%s\n' "$NEWEST"
printf 'crash_bytes='; wc -c < "$NEWEST"

python3 - "$NEWEST" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(errors='replace')
lines = text.splitlines()
objects = []
for candidate in [lines[0] if lines else '', '\n'.join(lines[1:]) if len(lines) > 1 else '', text]:
    if not candidate.strip():
        continue
    try:
        value = json.loads(candidate)
        if isinstance(value, dict):
            objects.append(value)
    except Exception:
        pass

header = objects[0] if objects else {}
body = objects[-1] if objects else {}
if len(objects) >= 2:
    header, body = objects[0], objects[1]

print('incident_id=' + str(header.get('incident_id') or body.get('incident') or 'unknown'))
print('timestamp=' + str(header.get('timestamp') or body.get('captureTime') or body.get('procLaunch') or 'unknown'))
print('process=' + str(body.get('procName') or header.get('app_name') or 'unknown'))
print('pid=' + str(body.get('pid') or 'unknown'))
print('os_version=' + str(body.get('osVersion') or header.get('os_version') or 'unknown'))
print('exception=' + json.dumps(body.get('exception') or {}, sort_keys=True))
print('termination=' + json.dumps(body.get('termination') or {}, sort_keys=True))
print('faulting_thread=' + str(body.get('faultingThread', 'unknown')))
print('last_exception_backtrace=' + json.dumps(body.get('lastExceptionBacktrace') or [], sort_keys=True))

images = body.get('usedImages') or []
for index, image in enumerate(images):
    name = str(image.get('name') or '')
    path_value = str(image.get('path') or '')
    if 'Gif2Ani' in name or 'Gif2Ani' in path_value:
        print(f'gif2ani_image_index={index}')
        print('gif2ani_image=' + json.dumps(image, sort_keys=True))

threads = body.get('threads') or []
fault = body.get('faultingThread')
if isinstance(fault, int) and 0 <= fault < len(threads):
    thread = threads[fault]
    print('faulting_thread_name=' + str(thread.get('name') or thread.get('queue') or 'unknown'))
    for frame_index, frame in enumerate((thread.get('frames') or [])[:40]):
        image_index = frame.get('imageIndex')
        image_name = ''
        if isinstance(image_index, int) and 0 <= image_index < len(images):
            image_name = str(images[image_index].get('name') or '')
        symbol = frame.get('symbol') or ''
        offset = frame.get('symbolLocation')
        image_offset = frame.get('imageOffset')
        print(f'frame_{frame_index}=image:{image_name}|symbol:{symbol}|symbolOffset:{offset}|imageOffset:{image_offset}')
else:
    print('faulting_thread_frames=unavailable')

# Also print a few direct textual clues in case the IPS parser shape differs.
needles = ('reason', 'exception', 'selector', 'unrecognized', 'NSInvalidArgument', 'NSInternalInconsistency', 'G2Theme', 'G2Open', 'G2Remote')
clues = []
for line in lines:
    if any(needle.lower() in line.lower() for needle in needles):
        clues.append(line[:1000])
    if len(clues) >= 20:
        break
for index, clue in enumerate(clues):
    print(f'text_clue_{index}={clue}')
PY

echo 'compact_crash_summary=complete'
