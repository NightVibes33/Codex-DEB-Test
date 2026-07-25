#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

python3 - <<'PY'
import json
import plistlib
import re
from pathlib import Path

print('=== Candidate installed jailbreak apps ===')
app_roots = [
    Path('/var/containers/Bundle/Application'),
    Path('/private/var/containers/Bundle/Application'),
    Path('/Applications'),
    Path('/var/jb/Applications'),
]
terms = ('dopamine', 'darksword', 'nightvibes', 'jailbreak')
candidates = []
seen = set()
for root in app_roots:
    if not root.exists():
        continue
    try:
        plists = root.rglob('*.app/Info.plist')
        for plist_path in plists:
            real = str(plist_path)
            if real in seen:
                continue
            seen.add(real)
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
                'short_version': str(info.get('CFBundleShortVersionString', '')),
                'build': str(info.get('CFBundleVersion', '')),
            }
            haystack = ' '.join(fields.values()).lower()
            if any(term in haystack for term in terms):
                app = plist_path.parent
                candidates.append((app, fields))
                print(f'app={app}')
                print(' '.join(f'{key}={value}' for key, value in fields.items()))
                binary = app / fields['executable']
                if binary.exists():
                    print(f'binary={binary} size={binary.stat().st_size}')

print(f'candidate_count={len(candidates)}')

print('\n=== Crash reports containing candidate identifiers ===')
log_roots = [
    Path('/var/mobile/Library/Logs/CrashReporter'),
    Path('/private/var/mobile/Library/Logs/CrashReporter'),
]
search_terms = set(terms)
for _, fields in candidates:
    for value in fields.values():
        value = value.strip().lower()
        if value:
            search_terms.add(value)
matched_reports = {}
for root in log_roots:
    if not root.exists():
        continue
    try:
        for path in root.rglob('*'):
            if not path.is_file():
                continue
            try:
                text = path.read_text(errors='replace')
            except Exception:
                continue
            lower = text.lower()
            hits = sorted(term for term in search_terms if term and term in lower)
            if hits:
                matched_reports[str(path)] = (path.stat().st_mtime, path, text, hits)
    except Exception:
        pass

summary_re = re.compile(
    r'(timestamp|bug_type|os_version|incident|procName|processName|bundleInfo|exception|termination|'
    r'jetsam|reason|footprint|rpages|panicString|panic string|cpu|wall|memory|Dopamine|DarkSword|NightVibes)',
    re.IGNORECASE,
)
for _, path, text, hits in sorted(matched_reports.values(), reverse=True)[:20]:
    print(f'--- report={path} hits={hits} ---')
    count = 0
    for line in text.splitlines():
        if summary_re.search(line):
            print(line[:1800])
            count += 1
            if count >= 100:
                break
print(f'matched_report_count={len(matched_reports)}')

print('\n=== Parsed latest jetsam process tables ===')
jet_items = {}
for root in log_roots:
    if not root.exists():
        continue
    try:
        for path in root.rglob('JetsamEvent-*.ips'):
            try:
                jet_items[str(path)] = (path.stat().st_mtime, path)
            except OSError:
                pass
    except Exception:
        pass

for _, path in sorted(jet_items.values(), reverse=True)[:8]:
    print(f'--- jetsam={path} ---')
    try:
        lines = path.read_text(errors='replace').splitlines()
        metadata = json.loads(lines[0]) if lines else {}
        payload = json.loads('\n'.join(lines[1:])) if len(lines) > 1 else {}
    except Exception as exc:
        print(f'parse_error={exc}')
        continue
    print(f"timestamp={metadata.get('timestamp')} incident={metadata.get('incident_id')} bug_type={metadata.get('bug_type')}")
    print(f"largestProcess={payload.get('largestProcess')} reason={payload.get('reason')} pageSize={payload.get('pageSize')}")
    processes = payload.get('processes') or []
    if isinstance(processes, dict):
        processes = list(processes.values())
    normalized = []
    for proc in processes:
        if not isinstance(proc, dict):
            continue
        name = proc.get('name') or proc.get('procName') or proc.get('processName') or proc.get('bundleIdentifier') or ''
        rpages = proc.get('rpages') or proc.get('pages') or proc.get('footprint') or 0
        try:
            sort_pages = int(rpages)
        except Exception:
            sort_pages = 0
        normalized.append((sort_pages, str(name), proc))
    for pages, name, proc in sorted(normalized, reverse=True)[:20]:
        print(
            f"process={name} pid={proc.get('pid')} rpages={pages} state={proc.get('state')} "
            f"reason={proc.get('reason')} priority={proc.get('priority')} coalition={proc.get('coalition')}"
        )
    for pages, name, proc in normalized:
        hay = (name + ' ' + json.dumps(proc, sort_keys=True)).lower()
        if any(term in hay for term in search_terms):
            print(f'candidate_process={name} rpages={pages} data={json.dumps(proc, sort_keys=True)[:1800]}')

print('\n=== Persistent DarkSword logs ===')
data_roots = [Path('/var/mobile/Containers/Data/Application'), Path('/private/var/mobile/Containers/Data/Application')]
stage_logs = {}
for root in data_roots:
    if root.exists():
        try:
            for path in root.rglob('DarkSword-iPad5.log'):
                try:
                    stage_logs[str(path)] = (path.stat().st_mtime, path)
                except OSError:
                    pass
        except Exception:
            pass
for _, path in sorted(stage_logs.values(), reverse=True)[:5]:
    print(f'--- stage_log={path} ---')
    try:
        for line in path.read_text(errors='replace').splitlines()[-200:]:
            print(line)
    except Exception as exc:
        print(f'read_error={exc}')
print(f'stage_log_count={len(stage_logs)}')
PY

echo "=== Current memory ==="
vm_stat 2>/dev/null | head -20 || true

echo "=== Done ==="
