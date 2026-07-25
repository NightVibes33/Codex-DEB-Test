#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile
REPO=/var/mobile/Documents/DarkSword-Workspace/Dopamine
TARGET="$REPO/Application/Dopamine/Exploits/DarkSword/DarkSword.m"

cd "$REPO"
echo '=== Repository state ==='
printf 'branch='; git branch --show-current
printf 'head='; git rev-parse HEAD
git status --short
printf 'origin='; git remote get-url origin

echo '=== Device ==='
uname -a
sysctl -n hw.memsize 2>/dev/null || true

echo '=== DarkSword source anchors ==='
python3 - "$TARGET" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1])
text=p.read_text()
lines=text.splitlines()
anchors=['fileport_t spray_socket', 'void pe_v1', 'totalSearchMappingPagesNum', 'surface_mlock(searchMappingAddress', 'sockets_release(socketPorts']
for anchor in anchors:
    hits=[i for i,l in enumerate(lines) if anchor in l]
    print(f'anchor={anchor!r} hits={len(hits)} lines={[i+1 for i in hits]}')
    for i in hits[:1]:
        lo=max(0,i-8); hi=min(len(lines),i+35)
        print(f'--- {anchor} context {lo+1}-{hi} ---')
        for n in range(lo,hi):
            print(f'{n+1:04d}: {lines[n]}')
PY

echo 'inspection=complete'
