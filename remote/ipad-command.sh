#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

WORK_ROOT="/var/mobile/Documents/DarkSword-Workspace"
BOOT_ROOT="$WORK_ROOT/.github-bootstrap"
PRIVATE_KEY="$BOOT_ROOT/bootstrap-private.pem"
PUBLIC_KEY="$BOOT_ROOT/bootstrap-public.pem"
mkdir -p "$BOOT_ROOT"
chmod 700 "$BOOT_ROOT"

printf 'openssl_path='; command -v openssl 2>/dev/null || true
if ! command -v openssl >/dev/null 2>&1; then
  echo "bootstrap_error=openssl-missing"
  exit 1
fi

if [ ! -s "$PRIVATE_KEY" ]; then
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$PRIVATE_KEY" >/dev/null 2>&1
  chmod 600 "$PRIVATE_KEY"
fi
openssl pkey -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY"
chmod 644 "$PUBLIC_KEY"

python3 - "$PUBLIC_KEY" <<'PY'
import base64
import sys
from pathlib import Path
path = Path(sys.argv[1])
print("BOOTSTRAP_PUBLIC_KEY_B64_BEGIN")
print(base64.b64encode(path.read_bytes()).decode("ascii"))
print("BOOTSTRAP_PUBLIC_KEY_B64_END")
PY

echo "bootstrap_private_key=$PRIVATE_KEY"
echo "bootstrap_status=ready"
