#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

python3 <<'PY'
import os
import subprocess
from pathlib import Path

work_root = Path('/var/mobile/Documents/DarkSword-Workspace')
repo_dir = work_root / 'Dopamine'
ssh_key = Path('/var/mobile/.ssh/id_ed25519')
ssh_wrapper = Path('/var/mobile/.ssh/github-ipad-ssh')
boot_private = work_root / '.github-bootstrap' / 'bootstrap-rsa-private.json'

if not (repo_dir / '.git').is_dir():
    raise SystemExit('push_error=ipad-repo-missing')
if not ssh_key.is_file():
    raise SystemExit('push_error=ipad-ssh-key-missing')

ssh_wrapper.write_text(
    '#!/bin/sh\n'
    'exec /var/jb/usr/bin/ssh -i /var/mobile/.ssh/id_ed25519 '
    '-o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$@"\n'
)
ssh_wrapper.chmod(0o700)

base_env = os.environ.copy()
base_env['HOME'] = '/var/mobile'
base_env['GIT_TERMINAL_PROMPT'] = '0'

print('=== GitHub SSH verification ===')
ssh_test = subprocess.run(
    [
        '/var/jb/usr/bin/ssh',
        '-i', str(ssh_key),
        '-o', 'IdentitiesOnly=yes',
        '-o', 'StrictHostKeyChecking=accept-new',
        '-T', 'git@github.com',
    ],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    env=base_env,
)
print(ssh_test.stdout.strip())
if 'successfully authenticated' not in ssh_test.stdout:
    raise SystemExit('ssh_authenticated=0')
print('ssh_authenticated=1')

subprocess.run(
    ['git', 'remote', 'set-url', 'origin', 'git@github.com:NightVibes33/Dopamine.git'],
    cwd=repo_dir,
    check=True,
    env=base_env,
)
local_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo_dir, text=True, env=base_env).strip()
local_subject = subprocess.check_output(['git', 'log', '-1', '--pretty=%s'], cwd=repo_dir, text=True, env=base_env).strip()
print(f'local_head={local_head}')
print(f'local_subject={local_subject}')

push_env = dict(base_env)
push_env['GIT_SSH'] = str(ssh_wrapper)
print('=== Push from iPad ===')
push = subprocess.run(
    ['git', 'push', 'origin', 'HEAD:main'],
    cwd=repo_dir,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    env=push_env,
)
print(push.stdout.strip())
print(f'push_exit_code={push.returncode}')
if push.returncode != 0:
    raise SystemExit('push_error=git-push-failed')

print('push=success')
print(f'pushed_head={local_head}')
boot_private.unlink(missing_ok=True)
try:
    boot_private.parent.rmdir()
except OSError:
    pass
print('bootstrap_private_key=erased')
print('github_auth=ssh-key')
PY
