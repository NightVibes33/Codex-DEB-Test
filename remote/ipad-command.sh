#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

WORK_ROOT="/var/mobile/Documents/DarkSword-Workspace"
BOOT_ROOT="$WORK_ROOT/.github-bootstrap"
PRIVATE_KEY="$BOOT_ROOT/bootstrap-rsa-private.json"
mkdir -p "$BOOT_ROOT"
chmod 700 "$BOOT_ROOT"

python3 - "$PRIVATE_KEY" <<'PY'
import json
import math
import secrets
import sys
from pathlib import Path

private_path = Path(sys.argv[1])
e = 65537

def is_probable_prime(n: int, rounds: int = 24) -> bool:
    small = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    if n in small:
        return True
    if n < 2 or any(n % p == 0 for p in small):
        return False
    d = n - 1
    s = 0
    while d % 2 == 0:
        s += 1
        d //= 2
    for _ in range(rounds):
        a = secrets.randbelow(n - 3) + 2
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True

def make_prime(bits: int) -> int:
    while True:
        value = secrets.randbits(bits) | (1 << (bits - 1)) | 1
        if is_probable_prime(value):
            return value

if private_path.exists():
    data = json.loads(private_path.read_text())
    n = int(data['n'], 16)
    d = int(data['d'], 16)
    e = int(data['e'])
else:
    while True:
        p = make_prime(1024)
        q = make_prime(1024)
        if p == q:
            continue
        phi = (p - 1) * (q - 1)
        if math.gcd(e, phi) != 1:
            continue
        n = p * q
        d = pow(e, -1, phi)
        break
    private_path.write_text(json.dumps({'n': hex(n), 'd': hex(d), 'e': e}))
    private_path.chmod(0o600)

print('BOOTSTRAP_RSA_N_HEX_BEGIN')
print(hex(n)[2:])
print('BOOTSTRAP_RSA_N_HEX_END')
print(f'BOOTSTRAP_RSA_E={e}')
print(f'BOOTSTRAP_RSA_BITS={n.bit_length()}')
print('bootstrap_status=ready')
PY
