#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== Memory before helper cleanup ==='
vm_stat 2>/dev/null | sed -n '1,20p' || true

python3 <<'PY'
import os
import re
import signal
import subprocess
import time

ALLOWLIST = {'dirtyZero', 'PureKFD', 'SparseBox', 'DebToIPA', 'NathanLR'}

text = subprocess.check_output(
    ['ps', '-axo', 'pid=,ppid=,etime=,command='],
    text=True,
    stderr=subprocess.STDOUT,
)

def elapsed_seconds(value: str) -> int:
    days = 0
    if '-' in value:
        d, value = value.split('-', 1)
        days = int(d)
    parts = [int(x) for x in value.split(':')]
    if len(parts) == 3:
        hours, minutes, seconds = parts
    elif len(parts) == 2:
        hours, minutes, seconds = 0, parts[0], parts[1]
    else:
        hours, minutes, seconds = 0, 0, parts[0]
    return days * 86400 + hours * 3600 + minutes * 60 + seconds

targets = []
for line in text.splitlines():
    m = re.match(r'^\s*(\d+)\s+(\d+)\s+(\S+)\s+(.*)$', line)
    if not m:
        continue
    pid_s, ppid_s, elapsed, command = m.groups()
    executable = command.strip().split(' ', 1)[0]
    name = os.path.basename(executable)
    if name not in ALLOWLIST:
        continue
    if int(ppid_s) != 1:
        continue
    if elapsed_seconds(elapsed) < 1800:
        continue
    targets.append((int(pid_s), name, elapsed, command.strip()))

print(f'target_count={len(targets)}')
for pid, name, elapsed, command in targets:
    print(f'terminating pid={pid} name={name} elapsed={elapsed} command={command[:300]}')
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass

time.sleep(3)
for pid, name, elapsed, command in targets:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        print(f'exited pid={pid} name={name} signal=TERM')
        continue
    print(f'forcing pid={pid} name={name} signal=KILL')
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass

time.sleep(1)
remaining = []
for pid, name, elapsed, command in targets:
    try:
        os.kill(pid, 0)
        remaining.append((pid, name))
    except ProcessLookupError:
        pass
print(f'remaining_target_count={len(remaining)}')
for pid, name in remaining:
    print(f'remaining pid={pid} name={name}')
PY

echo '=== Memory after helper cleanup ==='
vm_stat 2>/dev/null | sed -n '1,20p' || true
printf 'node_processes='; pgrep -x node 2>/dev/null | wc -l | tr -d ' '
printf 'all_processes='; ps -ax 2>/dev/null | wc -l | tr -d ' '
echo 'protected=Paleramine,sshd,system-daemons,active-apps'
