#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

python3 - <<'PY'
import json
import plistlib
from pathlib import Path

APP_ROOTS = [
    Path('/var/containers/Bundle/Application'),
    Path('/private/var/containers/Bundle/Application'),
    Path('/Applications'),
    Path('/var/jb/Applications'),
]
LOG_ROOTS = [
    Path('/var/mobile/Library/Logs/CrashReporter'),
    Path('/private/var/mobile/Library/Logs/CrashReporter'),
]
DATA_ROOTS = [
    Path('/var/mobile/Containers/Data/Application'),
    Path('/private/var/mobile/Containers/Data/Application'),
]
BASE_TERMS = {'dopamine', 'darksword', 'nightvibes', 'jailbreak'}

print('=== Candidate installed jailbreak apps ===')
candidates = []
seen = set()
for root in APP_ROOTS:
    if not root.exists():
        continue
    try:
        plist_paths = list(root.rglob('*.app/Info.plist'))
    except Exception:
        continue
    for plist_path in plist_paths:
        key = str(plist_path)
        if key in seen:
            continue
        seen.add(key)
        try:
            with plist_path.open('rb') as handle:
                info = plistlib.load(handle)
        except Exception:
            continue
        fields = {
            'bundle': str(info.get('CFBundleIdentifier', '')),
            'name': str(info.get('CFBundleName', '')),
            'display': str(info.get('CFBundleDisplayName', '')),
            'executable': str(info.get('CFBundleExecutable', '')),
            'version': str(info.get('CFBundleShortVersionString', '')),
            'build': str(info.get('CFBundleVersion', '')),
        }
        haystack = ' '.join(fields.values()).lower()
        if not any(term in haystack for term in BASE_TERMS):
            continue
        app_path = plist_path.parent
        candidates.append((app_path, fields))
        print(f'app={app_path}')
        print(' '.join(f'{name}={value}' for name, value in fields.items()))
        binary = app_path / fields['executable']
        if binary.exists():
            print(f'binary={binary} bytes={binary.stat().st_size}')
print(f'candidate_count={len(candidates)}')

search_terms = set(BASE_TERMS)
for _, fields in candidates:
    for value in fields.values():
        value = value.strip().lower()
        if value:
            search_terms.add(value)

print('\n=== Persistent DarkSword logs ===')
stage_logs = {}
for root in DATA_ROOTS:
    if not root.exists():
        continue
    try:
        paths = root.rglob('DarkSword-iPad5.log')
        for path in paths:
            try:
                stage_logs[str(path)] = (path.stat().st_mtime, path)
            except OSError:
                pass
    except Exception:
        pass
for _, path in sorted(stage_logs.values(), reverse=True)[:5]:
    print(f'--- {path} ---')
    try:
        for line in path.read_text(errors='replace').splitlines()[-150:]:
            print(line)
    except Exception as exc:
        print(f'read_error={exc}')
print(f'stage_log_count={len(stage_logs)}')

print('\n=== Reports matching jailbreak app identifiers ===')
reports = {}
for root in LOG_ROOTS:
    if not root.exists():
        continue
    try:
        paths = root.rglob('*')
        for path in paths:
            if not path.is_file():
                continue
            try:
                text = path.read_text(errors='replace')
                modified = path.stat().st_mtime
            except Exception:
                continue
            lower = text.lower()
            hits = sorted(term for term in search_terms if term and term in lower)
            if hits:
                reports[str(path)] = (modified, path, text, hits)
    except Exception:
        pass
for _, path, text, hits in sorted(reports.values(), reverse=True)[:12]:
    print(f'--- report={path} hits={hits} ---')
    printed = 0
    for line in text.splitlines():
        lower = line.lower()
        keys = ('timestamp', 'bug_type', 'procname', 'processname', 'bundleinfo', 'exception',
                'termination', 'jetsam', 'reason', 'footprint', 'rpages', 'panic',
                'cpu', 'wall', 'memory', 'dopamine', 'darksword', 'nightvibes')
        if any(key in lower for key in keys):
            print(line[:1800])
            printed += 1
            if printed >= 80:
                break
print(f'matched_report_count={len(reports)}')

print('\n=== Latest jetsam process tables ===')
jetsams = {}
for root in LOG_ROOTS:
    if not root.exists():
        continue
    try:
        for path in root.rglob('JetsamEvent-*.ips'):
            try:
                jetsams[str(path)] = (path.stat().st_mtime, path)
            except OSError:
                pass
    except Exception:
        pass
for _, path in sorted(jetsams.values(), reverse=True)[:8]:
    print(f'--- jetsam={path} ---')
    try:
        lines = path.read_text(errors='replace').splitlines()
        meta = json.loads(lines[0]) if lines else {}
        payload = json.loads('\n'.join(lines[1:])) if len(lines) > 1 else {}
    except Exception as exc:
        print(f'parse_error={exc}')
        continue
    print(f"timestamp={meta.get('timestamp')} incident={meta.get('incident_id')} bug_type={meta.get('bug_type')}")
    print(f"largestProcess={payload.get('largestProcess')} reason={payload.get('reason')} pageSize={payload.get('pageSize')}")
    processes = payload.get('processes') or []
    if isinstance(processes, dict):
        processes = list(processes.values())
    rows = []
    for proc in processes:
        if not isinstance(proc, dict):
            continue
        name = str(proc.get('name') or proc.get('procName') or proc.get('processName') or proc.get('bundleIdentifier') or '')
        raw_pages = proc.get('rpages') or proc.get('pages') or proc.get('footprint') or 0
        try:
            pages = int(raw_pages)
        except Exception:
            pages = 0
        rows.append((pages, name, proc))
    for pages, name, proc in sorted(rows, reverse=True)[:15]:
        print(f"process={name} pid={proc.get('pid')} rpages={pages} state={proc.get('state')} reason={proc.get('reason')}")
    for pages, name, proc in rows:
        serialized = (name + ' ' + json.dumps(proc, sort_keys=True)).lower()
        if any(term in serialized for term in search_terms):
            print(f'candidate_process={name} rpages={pages} data={json.dumps(proc, sort_keys=True)[:1800]}')

print('\n=== Diagnostic complete ===')
PY

vm_stat 2>/dev/null | head -20 || true
