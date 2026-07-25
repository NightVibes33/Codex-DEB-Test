#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

python3 <<'PY'
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

repo = Path('/var/mobile/Documents/DarkSword-Workspace/Dopamine')
target = repo / 'Application/Dopamine/Exploits/DarkSword/DarkSword.m'
branch = 'ipad5/adaptive-lowmem-v1'
ssh_key = Path('/var/mobile/.ssh/id_ed25519')
ssh_wrapper = Path('/var/mobile/.ssh/github-ipad-ssh')
source_url = 'https://raw.githubusercontent.com/NightVibes33/Codex-DEB-Test/492bf619e7abf1e3bcaa8ad01c624c27fbacc5d9/remote/ipad-command.sh'

if not ssh_key.is_file():
    raise SystemExit('driver_error=ipad-ssh-key-missing')
if not (repo / '.git').is_dir():
    raise SystemExit('driver_error=dopamine-workspace-missing')

ssh_wrapper.write_text(
    '#!/bin/sh\n'
    'exec /var/jb/usr/bin/ssh -i /var/mobile/.ssh/id_ed25519 '
    '-o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$@"\n'
)
ssh_wrapper.chmod(0o700)

env = os.environ.copy()
env['HOME'] = '/var/mobile'
env['GIT_SSH'] = str(ssh_wrapper)
env['GIT_TERMINAL_PROMPT'] = '0'

def run(args, *, cwd=repo, check=True, capture=False):
    print('+', ' '.join(map(str, args)), flush=True)
    result = subprocess.run(
        [str(x) for x in args], cwd=cwd, env=env, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    if capture and result.stdout:
        print(result.stdout.rstrip(), flush=True)
    if check and result.returncode != 0:
        raise SystemExit(f'driver_error=command-failed:{args[0]}:{result.returncode}')
    return result

print('=== GitHub SSH verification ===', flush=True)
ssh = run([
    '/var/jb/usr/bin/ssh', '-i', ssh_key, '-o', 'IdentitiesOnly=yes',
    '-o', 'StrictHostKeyChecking=accept-new', '-T', 'git@github.com'
], cwd=repo, check=False, capture=True)
if 'successfully authenticated' not in (ssh.stdout or ''):
    raise SystemExit('driver_error=github-ssh-auth-failed')

print('=== Reset isolated branch from main ===', flush=True)
run(['git', 'fetch', 'origin', 'main'])
run(['git', 'reset', '--hard', 'origin/main'])
run(['git', 'clean', '-fd'])
run(['git', 'switch', '-C', branch, 'origin/main'])
run(['git', 'config', 'user.name', 'NightVibes33 iPad'])
run(['git', 'config', 'user.email', 'NightVibes33@users.noreply.github.com'])

print('=== Extract and apply preserved Python patch payload ===', flush=True)
with urllib.request.urlopen(source_url, timeout=30) as response:
    shell_source = response.read().decode('utf-8')
start_marker = 'python3 - "$TARGET" <<\'PY\'\n'
end_marker = '\nPY\n\nmkdir -p research\n'
start = shell_source.find(start_marker)
if start < 0:
    raise SystemExit('driver_error=patch-start-marker-missing')
start += len(start_marker)
end = shell_source.find(end_marker, start)
if end < 0:
    raise SystemExit('driver_error=patch-end-marker-missing')
patch_source = shell_source[start:end]
patch_file = Path('/tmp/ipad5-darksword-patcher.py')
patch_file.write_text(patch_source)
run(['python3', patch_file, target], cwd=repo)
patch_file.unlink(missing_ok=True)

research = repo / 'research/IPAD5_ADAPTIVE_LOWMEM_V1.md'
research.parent.mkdir(parents=True, exist_ok=True)
research.write_text('''# iPad 5 DarkSword adaptive low-memory profile v1

Target: iPad6,11 / iPad6,12 on iOS 16.7.x only.

Changes:
- Keeps the stock DarkSword path unchanged for all other devices.
- Frees the 0x400-byte userspace socket metadata buffer after every spray.
- Validates socket/fileport creation and short metadata responses.
- Calls `surface_munlock` for every scanned search mapping before deallocation.
- Uses bounded profiles: 512 MB + 16,384 sockets, 384 MB + 12,288 sockets, and 256 MB + 8,192 sockets.
- Runs two clean attempts per profile and exits with an error after six misses.
- Preserves stdout and writes sparse stage/memory telemetry to `DarkSword-iPad5-Adaptive.log`.

This branch must be validated from a stock boot. A successful build does not prove exploitation success.
''')

print('=== Static invariants ===', flush=True)
text = target.read_text()
checks = {
    'adaptive-marker': 'iPad5-Adaptive',
    'device-gate': 'strstr(name.machine, "iPad6,11")',
    '512-profile': '{ 0x8000, 0x1000, 16384, 2',
    '384-profile': '{ 0x6000, 0x0C00, 12288, 2',
    '256-profile': '{ 0x4000, 0x0800,  8192, 2',
    'socket-free': 'free(socketInfo);',
    'mapping-unlock': 'surface_munlock(searchMappingAddress, searchMappingSize);',
    'bounded-failure': 'profiles-exhausted',
}
for name, needle in checks.items():
    count = text.count(needle)
    print(f'check={name} count={count}', flush=True)
    if count < 1:
        raise SystemExit(f'driver_error=static-check-missing:{name}')
if 'freopen(' in text:
    raise SystemExit('driver_error=unsafe-stdout-redirection')
run(['git', 'diff', '--check'])
print('static_checks=success', flush=True)

run(['git', 'status', '--short'], capture=True)
run(['git', 'diff', '--stat'], capture=True)
run(['git', 'add', str(target.relative_to(repo)), str(research.relative_to(repo))])
run(['git', 'commit', '-m', 'Add adaptive low-memory DarkSword profile for iPad 5'])
head = run(['git', 'rev-parse', 'HEAD'], capture=True).stdout.strip()
run(['git', 'push', '--force-with-lease', '-u', 'origin', branch])
print(f'branch={branch}', flush=True)
print(f'pushed_head={head}', flush=True)
print('ipad_push=success', flush=True)
PY
