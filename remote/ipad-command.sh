#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

echo '=== iPad dual-boot storage feasibility ==='
printf 'verified_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'identity='; id
printf 'model='; sysctl -n hw.model 2>/dev/null || true

if [ -f /System/Library/CoreServices/SystemVersion.plist ] && command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import plistlib
p='/System/Library/CoreServices/SystemVersion.plist'
with open(p,'rb') as f: d=plistlib.load(f)
print('ios_version=' + str(d.get('ProductVersion','')))
print('ios_build=' + str(d.get('ProductBuildVersion','')))
PY
fi

echo '=== Filesystem capacity ==='
for p in / /private/var /var/mobile /private/preboot /var/jb; do
  if [ -e "$p" ]; then
    echo "path=$p"
    df -h "$p" 2>/dev/null | tail -n 1 || true
    df -k "$p" 2>/dev/null | tail -n 1 || true
  fi
done

if command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import os
for p in ['/', '/private/var', '/var/mobile', '/private/preboot', '/var/jb']:
    try:
        s=os.statvfs(p)
    except OSError:
        continue
    total=s.f_blocks*s.f_frsize
    free=s.f_bavail*s.f_frsize
    used=total-free
    print(f'statvfs path={p} total_bytes={total} used_bytes={used} available_bytes={free} total_gib={total/2**30:.2f} used_gib={used/2**30:.2f} available_gib={free/2**30:.2f}')
PY
fi

echo '=== Key storage consumers ==='
for p in /private/preboot /var/mobile /var/jb; do
  [ -e "$p" ] || continue
  du -sk "$p" 2>/dev/null | awk -v path="$p" '{printf "du path=%s kib=%s gib=%.2f\n", path, $1, $1/1048576}' || true
done

echo '=== Mount layout ==='
mount 2>/dev/null | grep -E '(/private/var|/private/preboot| on / |/var/jb)' || true

echo 'verification=read-only-complete'