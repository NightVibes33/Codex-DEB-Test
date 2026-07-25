#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== Memory before cleanup ==='
vm_stat 2>/dev/null | sed -n '1,20p' || true
printf 'node_count='; pgrep -x node 2>/dev/null | wc -l | tr -d ' '

echo '=== Live Node process inventory ==='
python3 <<'PY'
import os
import re
import subprocess

try:
    text = subprocess.check_output(
        ['ps', '-axo', 'pid=,ppid=,etime=,state=,command='],
        text=True,
        stderr=subprocess.STDOUT,
    )
except subprocess.CalledProcessError as exc:
    print(exc.output)
    raise

rows = []
for line in text.splitlines():
    match = re.match(r'^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(.*)$', line)
    if not match:
        continue
    pid, ppid, elapsed, state, command = match.groups()
    executable = command.strip().split(' ', 1)[0]
    if os.path.basename(executable) != 'node':
        continue
    rows.append((int(pid), int(ppid), elapsed, state, command.strip()))

all_pids = {int(m.group(1)) for line in text.splitlines() if (m := re.match(r'^\s*(\d+)\s+', line))}
print(f'live_node_count={len(rows)}')
for pid, ppid, elapsed, state, command in rows:
    parent_exists = int(ppid in all_pids)
    print(f'node pid={pid} ppid={ppid} parent_exists={parent_exists} elapsed={elapsed} state={state} command={command[:400]}')
    if subprocess.call(['sh', '-c', 'command -v lsof >/dev/null 2>&1']) == 0:
        try:
            details = subprocess.check_output(
                ['lsof', '-a', '-p', str(pid), '-d', 'cwd', '-Fn'],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=4,
            ).strip().replace('\n', ' ')
            if details:
                print(f'cwd pid={pid} {details[:500]}')
        except Exception:
            pass
PY

echo '=== Parent process snapshot ==='
for pid in $(pgrep -x node 2>/dev/null || true); do
  ppid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)
  [ -n "$ppid" ] || continue
  ps -p "$ppid" -o pid=,ppid=,etime=,state=,command= 2>/dev/null || true
done

echo 'cleanup_phase=inventory-only'
