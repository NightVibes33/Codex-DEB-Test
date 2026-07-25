#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

python3 <<'PY'
import json
import os
import re
import time
from pathlib import Path

roots = [
    Path('/var/mobile/Library/Logs/CrashReporter'),
    Path('/private/var/mobile/Library/Logs/CrashReporter'),
]
keywords = (
    'paleramine', 'dopamine', 'darksword',
    'com.nightvibes33.paleramine', 'com.nightvibes33.dopamine',
    'springboard', 'backboardd', 'jetsamevent', 'panic-full',
    'vm-compressor-space-shortage',
)
cutoff = time.time() - (7 * 24 * 60 * 60)
seen = set()
files = []

for root in roots:
    if not root.is_dir():
        continue
    for path in root.iterdir():
        try:
            stat = path.stat()
        except OSError:
            continue
        if not path.is_file() or stat.st_mtime < cutoff:
            continue
        key = (path.name, stat.st_size, int(stat.st_mtime))
        if key in seen:
            continue
        seen.add(key)
        files.append((stat.st_mtime, path, stat.st_size))

files.sort(reverse=True)
print('=== Current jailbreak-related crash inventory ===')
print(f'scan_time={time.strftime("%Y-%m-%dT%H:%M:%S%z")})')
print(f'reports_last_7_days={len(files)}')


def load_objects(path: Path):
    objects = []
    try:
        with path.open('r', encoding='utf-8', errors='replace') as handle:
            for _ in range(3):
                line = handle.readline()
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    value = json.loads(line)
                    if isinstance(value, dict):
                        objects.append(value)
                except Exception:
                    pass
    except OSError:
        pass
    return objects


def find_value(obj, names):
    if isinstance(obj, dict):
        for name in names:
            if name in obj and obj[name] not in (None, '', [], {}):
                return obj[name]
        for value in obj.values():
            found = find_value(value, names)
            if found not in (None, '', [], {}):
                return found
    elif isinstance(obj, list):
        for value in obj:
            found = find_value(value, names)
            if found not in (None, '', [], {}):
                return found
    return None


def compact(value, limit=500):
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        text = json.dumps(value, sort_keys=True, separators=(',', ':'))
    else:
        text = str(value)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:limit]

relevant = []
for mtime, path, size in files[:80]:
    name_lower = path.name.lower()
    sample = ''
    try:
        with path.open('r', encoding='utf-8', errors='replace') as handle:
            sample = handle.read(min(size, 2_000_000)).lower()
    except OSError:
        pass
    if any(term in name_lower or term in sample for term in keywords):
        relevant.append((mtime, path, size, sample))

print(f'relevant_reports={len(relevant)}')
for index, (mtime, path, size, sample) in enumerate(relevant[:20], 1):
    objects = load_objects(path)
    merged = {}
    for obj in objects:
        merged.update(obj)

    print(f'--- report={index} ---')
    print(f'file={path.name}')
    print(f'modified={time.strftime("%Y-%m-%d %H:%M:%S %z", time.localtime(mtime))}')
    print(f'bytes={size}')

    fields = {
        'timestamp': find_value(objects, ['timestamp', 'captureTime', 'incidentTimestamp']),
        'incident': find_value(objects, ['incident_id', 'incident', 'incidentId']),
        'bug_type': find_value(objects, ['bug_type', 'bugType']),
        'process': find_value(objects, ['procName', 'processName', 'app_name', 'largestProcess']),
        'bundle': find_value(objects, ['bundleID', 'bundleIdentifier', 'bundle_id']),
        'os_version': find_value(objects, ['os_version', 'osVersion']),
        'exception': find_value(objects, ['exception', 'exceptionType', 'exceptionCodes']),
        'termination': find_value(objects, ['termination', 'terminationReason']),
        'panic': find_value(objects, ['panicString', 'panic_string']),
        'reason': find_value(objects, ['reason', 'killReason']),
    }
    for key, value in fields.items():
        text = compact(value)
        if text:
            print(f'{key}={text}')

    # Jetsam-specific process rows relevant to jailbreak or compressor pressure.
    processes = find_value(objects, ['processes'])
    if isinstance(processes, list):
        rows = []
        for proc in processes:
            if not isinstance(proc, dict):
                continue
            pname = str(proc.get('name') or proc.get('procName') or '')
            preason = str(proc.get('reason') or '')
            if any(term in (pname + ' ' + preason).lower() for term in keywords):
                rows.append({
                    'name': pname,
                    'pid': proc.get('pid'),
                    'reason': preason or None,
                    'rpages': proc.get('rpages'),
                    'priority': proc.get('priority'),
                    'state': proc.get('state'),
                })
        for row in rows[:10]:
            print('jetsam_process=' + compact(row, 400))

    memory_status = find_value(objects, ['memoryStatus'])
    if isinstance(memory_status, dict):
        selected = {
            key: memory_status.get(key)
            for key in ('compressions', 'decompressions', 'compressorSize', 'uncompressed', 'zoneMapSize', 'zoneMapCap')
            if memory_status.get(key) is not None
        }
        pages = memory_status.get('memoryPages')
        if isinstance(pages, dict):
            selected['memoryPages'] = {
                key: pages.get(key)
                for key in ('free', 'active', 'inactive', 'wired', 'anonymous', 'fileBacked')
                if pages.get(key) is not None
            }
        if selected:
            print('memory_status=' + compact(selected, 800))

    # Fallback string clues when the report is not JSON-line formatted.
    clues = []
    for pattern in (
        r'vm-compressor-space-shortage',
        r'EXC_[A-Z_]+',
        r'Namespace [A-Z]+, Code [^\n]{1,120}',
        r'panic\([^\n]{1,300}',
        r'Paleramine[^\n]{0,200}',
        r'Dopamine[^\n]{0,200}',
        r'DarkSword[^\n]{0,200}',
    ):
        match = re.search(pattern, sample, flags=re.IGNORECASE)
        if match:
            clues.append(match.group(0))
    for clue in clues[:5]:
        print('clue=' + compact(clue, 350))

print('=== Installed jailbreak apps ===')
for base in (Path('/var/containers/Bundle/Application'), Path('/private/var/containers/Bundle/Application')):
    if not base.is_dir():
        continue
    for app in base.glob('*/*.app'):
        lower = app.name.lower()
        if 'paler' in lower or 'dopamine' in lower:
            try:
                print(f'app={app} modified={time.strftime("%Y-%m-%d %H:%M:%S %z", time.localtime(app.stat().st_mtime))}')
            except OSError:
                print(f'app={app}')
print('=== End crash scan ===')
PY