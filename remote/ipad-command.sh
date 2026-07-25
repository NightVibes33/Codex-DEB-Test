#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME="/var/mobile"

WORK_ROOT="/var/mobile/Documents/DarkSword-Workspace"
BOOT_ROOT="$WORK_ROOT/.github-bootstrap"
PRIVATE_KEY="$BOOT_ROOT/bootstrap-rsa-private.json"
REPO_DIR="$WORK_ROOT/Dopamine"
SSH_KEY="/var/mobile/.ssh/id_ed25519"
CIPHERTEXT_B64='D5l01963T0NpVj6SoSyBNkiIIhIZHOCh+FEveaLX9UNjpidGoV6bS6wVnq0piBWAyJSbO+AcjH4X/4SQfAjxLzFtK4hF73lGnh0FzDzjKykigaeIa+mqOTdv6iqEl90i8xlJin8ChEPU47tl/Kr//1w5arfD6um2lIdw5FZtDz24skRDKo1pyu6e85oF4eqGm57ahY5PL0s0MBBy0hY207q4+tr2ufZAgmnB045kduP9UxAEme3CieVLMNyA5j2mYuLBrSSp8Z5KOU9gl9RZ9dK/jC5Op0E++m5FBF1W6fquAhDE0BxkesiJWuP9Mss7RsF6inTkvpemUmFVIFPyQg=='

python3 - "$PRIVATE_KEY" "$REPO_DIR" "$SSH_KEY" "$CIPHERTEXT_B64" <<'PY'
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

private_path = Path(sys.argv[1])
repo_dir = Path(sys.argv[2])
ssh_key = Path(sys.argv[3])
ciphertext = base64.b64decode(sys.argv[4])

if not private_path.exists():
    raise SystemExit('bootstrap_error=private-key-missing')
if not repo_dir.joinpath('.git').exists():
    raise SystemExit('bootstrap_error=ipad-repo-missing')
if not ssh_key.exists() or not ssh_key.with_suffix('.pub').exists():
    raise SystemExit('bootstrap_error=ipad-ssh-key-missing')

key_data = json.loads(private_path.read_text())
n = int(key_data['n'], 16)
d = int(key_data['d'], 16)
k = (n.bit_length() + 7) // 8

def mgf1(seed: bytes, length: int) -> bytes:
    out = b''
    counter = 0
    while len(out) < length:
        out += hashlib.sha256(seed + counter.to_bytes(4, 'big')).digest()
        counter += 1
    return out[:length]

c = int.from_bytes(ciphertext, 'big')
em = pow(c, d, n).to_bytes(k, 'big')
hlen = hashlib.sha256().digest_size
if len(em) < 2 * hlen + 2 or em[0] != 0:
    raise SystemExit('bootstrap_error=oaep-header')
masked_seed = em[1:1 + hlen]
masked_db = em[1 + hlen:]
seed_mask = mgf1(masked_db, hlen)
seed = bytes(a ^ b for a, b in zip(masked_seed, seed_mask))
db_mask = mgf1(seed, k - hlen - 1)
db = bytes(a ^ b for a, b in zip(masked_db, db_mask))
expected_hash = hashlib.sha256(b'').digest()
if db[:hlen] != expected_hash:
    raise SystemExit('bootstrap_error=oaep-hash')
rest = db[hlen:]
try:
    separator = rest.index(b'\x01')
except ValueError:
    raise SystemExit('bootstrap_error=oaep-separator')
if any(rest[:separator]):
    raise SystemExit('bootstrap_error=oaep-padding')
token = rest[separator + 1:].decode('ascii')
print('token_decrypt=success')

api_root = 'https://api.github.com'
headers = {
    'Accept': 'application/vnd.github+json',
    'Authorization': f'Bearer {token}',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'NightVibes33-iPad6,11-DarkSword',
}

def api(method: str, path: str, payload=None):
    body = None
    request_headers = dict(headers)
    if payload is not None:
        body = json.dumps(payload).encode('utf-8')
        request_headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(api_root + path, data=body, headers=request_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            parsed = json.loads(raw) if raw else None
        except Exception:
            parsed = {'message': raw.decode('utf-8', errors='replace')}
        return exc.code, parsed

status, profile = api('GET', '/user')
if status != 200:
    print(f'github_token_status={status}')
    raise SystemExit('bootstrap_error=token-rejected')
print(f"github_login={profile.get('login', '')}")

public_key = ssh_key.with_suffix('.pub').read_text().strip()
public_key_core = ' '.join(public_key.split()[:2])
auth_mode = ''

status, keys = api('GET', '/user/keys')
if status == 200 and isinstance(keys, list):
    for item in keys:
        if str(item.get('key', '')).startswith(public_key_core):
            auth_mode = 'account-key-existing'
            break
if not auth_mode:
    status, result = api('POST', '/user/keys', {
        'title': 'Bobbys iPad6,11 DarkSword',
        'key': public_key,
    })
    if status == 201:
        auth_mode = 'account-key-created'
    else:
        print(f'account_key_api_status={status}')

if not auth_mode:
    status, keys = api('GET', '/repos/NightVibes33/Dopamine/keys?per_page=100')
    if status == 200 and isinstance(keys, list):
        for item in keys:
            if str(item.get('key', '')).startswith(public_key_core):
                auth_mode = 'deploy-key-existing'
                break
if not auth_mode:
    status, result = api('POST', '/repos/NightVibes33/Dopamine/keys', {
        'title': 'Bobbys iPad6,11 DarkSword',
        'key': public_key,
        'read_only': False,
    })
    if status == 201:
        auth_mode = 'deploy-key-created'
    else:
        print(f'deploy_key_api_status={status}')

print(f'ssh_authorization={auth_mode or "api-unavailable"}')

env = os.environ.copy()
env['HOME'] = '/var/mobile'
env['GIT_TERMINAL_PROMPT'] = '0'
env['GIT_SSH_COMMAND'] = f'ssh -i {ssh_key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new'
subprocess.run(['git', 'remote', 'set-url', 'origin', 'git@github.com:NightVibes33/Dopamine.git'], cwd=repo_dir, check=True, env=env)
ssh_test = subprocess.run(
    ['ssh', '-i', str(ssh_key), '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=accept-new', '-T', 'git@github.com'],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    env=env,
)
ssh_text = ssh_test.stdout.strip()
print('ssh_test=' + ('authenticated' if 'successfully authenticated' in ssh_text else 'not-authenticated'))

push = None
if 'successfully authenticated' in ssh_text:
    push = subprocess.run(['git', 'push', 'origin', 'HEAD:main'], cwd=repo_dir, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
else:
    askpass_dir = Path(tempfile.mkdtemp(prefix='ipad-gh-'))
    token_file = askpass_dir / 'token'
    askpass = askpass_dir / 'askpass.sh'
    token_file.write_text(token)
    token_file.chmod(0o600)
    askpass.write_text('#!/bin/sh\ncase "$1" in\n  *Username*) echo x-access-token ;;\n  *) cat "' + str(token_file) + '" ;;\nesac\n')
    askpass.chmod(0o700)
    https_env = dict(env)
    https_env['GIT_ASKPASS'] = str(askpass)
    push = subprocess.run(
        ['git', 'push', 'https://github.com/NightVibes33/Dopamine.git', 'HEAD:main'],
        cwd=repo_dir,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=https_env,
    )
    try:
        token_file.unlink(missing_ok=True)
        askpass.unlink(missing_ok=True)
        askpass_dir.rmdir()
    except Exception:
        pass

safe_output = push.stdout.replace(token, '[redacted]')
print(safe_output[-3000:])
print(f'push_exit_code={push.returncode}')
if push.returncode != 0:
    raise SystemExit('bootstrap_error=push-failed')

print('push=success')
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo_dir, text=True, env=env).strip()
print(f'pushed_head={head}')

private_path.unlink(missing_ok=True)
print('bootstrap_private_key=erased')
token = ''
PY
