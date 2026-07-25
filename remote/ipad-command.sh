#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

python3 - <<'PY'
import json
from pathlib import Path

roots = [
    Path('/var/mobile/Library/Logs/CrashReporter'),
    Path('/private/var/mobile/Library/Logs/CrashReporter'),
]
terms = ('paleramine', 'dopamine', 'darksword', 'nightvibes')

print('=== Latest jetsam process tables ===')
items = {}
for root in roots:
    if not root.exists():
        continue
    try:
        for path in root.rglob('JetsamEvent-*.ips'):
            try:
                items[str(path)] = (path.stat().st_mtime, path)
            except OSError:
                pass
    except Exception:
        pass

for _, path in sorted(items.values(), key=lambda item: item[0], reverse=True)[:12]:
    print(f'--- {path} ---')
    try:
        lines = path.read_text(errors='replace').splitlines()
        meta = json.loads(lines[0]) if lines else {}
        payload = json.loads('\n'.join(lines[1:])) if len(lines) > 1 else {}
    except Exception as exc:
        print(f'parse_error={exc}')
        continue

    print(f"timestamp={meta.get('timestamp')} incident={meta.get('incident_id')} bug_type={meta.get('bug_type')}")
    print(f"largestProcess={payload.get('largestProcess')} reason={payload.get('reason')} pageSize={payload.get('pageSize')}")
    memory_status = payload.get('memoryStatus') or {}
    memory_pages = payload.get('memoryPages') or {}
    print(f'memoryStatus={json.dumps(memory_status, sort_keys=True)[:1200]}')
    print(f'memoryPages={json.dumps(memory_pages, sort_keys=True)[:1200]}')

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

    ordered = sorted(rows, key=lambda row: (row[0], row[1]), reverse=True)
    for pages, name, proc in ordered[:20]:
        print(
            f"top_process={name} pid={proc.get('pid')} rpages={pages} "
            f"cpuTime={proc.get('cpuTime')} state={proc.get('state')} "
            f"reason={proc.get('reason')} priority={proc.get('priority')}"
        )

    matched = False
    for pages, name, proc in ordered:
        serialized = (name + ' ' + json.dumps(proc, sort_keys=True)).lower()
        if any(term in serialized for term in terms):
            matched = True
            print(f'candidate_process={name} rpages={pages}')
            print(json.dumps(proc, indent=2, sort_keys=True)[:8000])
    if not matched:
        print('candidate_process=not-present')

print('=== Paleramine bundle ===')
for path in [
    Path('/var/containers/Bundle/Application/EBC0B1B9-0064-43EA-B0B1-A6F742F41FD2/Paleramine.app/Paleramine'),
    Path('/private/var/containers/Bundle/Application/EBC0B1B9-0064-43EA-B0B1-A6F742F41FD2/Paleramine.app/Paleramine'),
]:
    if path.exists():
        print(f'binary={path} bytes={path.stat().st_size}')

print('=== Done ===')
PY
