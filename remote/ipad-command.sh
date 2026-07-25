#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/usr/sbin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

python3 <<'PY'
import os
import subprocess
from pathlib import Path

repo = Path('/var/mobile/Documents/DarkSword-Workspace/Dopamine')
branch = 'ipad5/adaptive-lowmem-v1'
expected_remote = '0ae85378a6294a424c8b63de0c72b8eb8161447f'
expected_local = '027e478f8e16fd9d8044fc29cade307c65cb3715'
ssh_key = Path('/var/mobile/.ssh/id_ed25519')
ssh_wrapper = Path('/var/mobile/.ssh/github-ipad-ssh')

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

def run(args, check=True):
    print('+', ' '.join(args), flush=True)
    p = subprocess.run(args, cwd=repo, env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if p.stdout:
        print(p.stdout.rstrip(), flush=True)
    if check and p.returncode != 0:
        raise SystemExit(f'publish_error=command-failed:{args[0]}:{p.returncode}')
    return p

local = run(['git', 'rev-parse', 'HEAD']).stdout.strip()
current_branch = run(['git', 'branch', '--show-current']).stdout.strip()
print(f'current_branch={current_branch}')
print(f'local_head={local}')
if current_branch != branch or local != expected_local:
    raise SystemExit('publish_error=unexpected-local-state')

run(['git', 'fetch', 'origin', branch])
remote = run(['git', 'rev-parse', 'FETCH_HEAD']).stdout.strip()
print(f'remote_head_before={remote}')
if remote != expected_remote:
    raise SystemExit('publish_error=remote-branch-changed')

lease = f'--force-with-lease=refs/heads/{branch}:{expected_remote}'
run(['git', 'push', lease, '-u', 'origin', f'HEAD:refs/heads/{branch}'])
print(f'branch={branch}')
print(f'pushed_head={local}')
print('ipad_push=success')
PY
