#!/bin/sh
set -eu

export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

printf '%s\n' '=== iPad rootless jailbreak verification ==='
printf 'verified_at_utc='; date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
printf 'effective_identity='; id
printf 'kernel_machine='; uname -m
printf 'kernel_release='; uname -r

if command -v sysctl >/dev/null 2>&1; then
  printf 'hardware_model='; sysctl -n hw.model 2>/dev/null || true
fi

SYSTEM_VERSION_PLIST=/System/Library/CoreServices/SystemVersion.plist
if [ -f "$SYSTEM_VERSION_PLIST" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$SYSTEM_VERSION_PLIST" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as handle:
    data = plistlib.load(handle)
print('product_name=' + str(data.get('ProductName', '')))
print('product_version=' + str(data.get('ProductVersion', '')))
print('build_version=' + str(data.get('ProductBuildVersion', '')))
PY
fi

if [ -d /var/jb ]; then
  echo 'rootless_prefix=/var/jb'
  echo 'rootless_prefix_present=yes'
  ls -ld /var/jb
else
  echo 'rootless_prefix_present=no'
fi

if command -v dpkg >/dev/null 2>&1; then
  printf 'dpkg_architecture='; dpkg --print-architecture 2>/dev/null || true
  echo 'jailbreak_packages_begin'
  dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | grep -Ei 'palera1n|ellekit|substitute|substrate|sileo|zebra|procursus' || true
  echo 'jailbreak_packages_end'
else
  echo 'dpkg_present=no'
fi

for path in \
  /var/jb/Library/MobileSubstrate/DynamicLibraries \
  /var/jb/usr/lib/TweakInject \
  /var/jb/Library/PreferenceBundles \
  /var/jb/usr/bin \
  /var/jb/usr/lib; do
  if [ -e "$path" ]; then
    printf 'path_present=yes path=%s\n' "$path"
  else
    printf 'path_present=no path=%s\n' "$path"
  fi
done

if [ -f /var/jb/.installed_palera1n ]; then
  echo 'palera1n_marker=/var/jb/.installed_palera1n'
fi

printf '%s\n' 'verification_result=completed-read-only'
