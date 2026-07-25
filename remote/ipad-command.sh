#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
python3 <<'PY'
import json
from pathlib import Path

root = Path('/var/mobile/Library/Logs/CrashReporter')
files = sorted(root.glob('JetsamEvent-*.ips'), key=lambda p: p.stat().st_mtime, reverse=True)[:5]
for path in files:
    lines = path.read_text(errors='replace').splitlines()
    meta = json.loads(lines[0]) if lines else {}
    data = json.loads('\n'.join(lines[1:])) if len(lines) > 1 else {}
    print('---')
    print('file=' + path.name)
    print('timestamp=' + str(meta.get('timestamp')))
    print('largest=' + str(data.get('largestProcess')))
    memory = data.get('memoryStatus') or {}
    pages = memory.get('memoryPages') or {}
    print('free_pages=' + str(pages.get('free')))
    print('compressor_size=' + str(memory.get('compressorSize')))
    procs = data.get('processes') or []
    procs = sorted(procs, key=lambda p: int(p.get('rpages') or 0), reverse=True)
    for proc in procs[:15]:
        print('proc=' + json.dumps({
            'name': proc.get('name'),
            'pid': proc.get('pid'),
            'rpages': proc.get('rpages'),
            'reason': proc.get('reason'),
            'priority': proc.get('priority')
        }, separators=(',', ':')))
PY