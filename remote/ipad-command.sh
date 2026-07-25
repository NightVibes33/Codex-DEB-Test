#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

python3 <<'PY'
import hashlib
import os
import plistlib
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

url = 'https://sdmntprwestus3.oaiusercontent.com/files/00000000-7d88-81fd-bb6b-818045031037/raw?se=2026-07-25T08:51:19Z&sp=r&sv=2026-02-06&sr=b&scid=1b301e93-e3fa-523c-a204-65e143bc4c7d&skoid=2d2fbb03-9efb-4ad0-a91c-1db2f5a47997&sktid=a48cca56-e6da-484e-a814-9c849652bcb3&skt=2026-07-25T08:06:38Z&ske=2026-07-27T08:06:38Z&sks=b&skv=2026-02-06&sig=dCoxzxYeISnZBzdO4qQdn0rz32XWz%2B%2BhtvsgDU2v084%3D'
expected_ipa_sha = '8cd2777ac994a6b56d401044ba8de0940d08b6fec847b3e0fae25ecac685250a'
expected_source_sha = '020358a8549ab0a33482d3656b42ed3809fc515f'
root = Path('/var/mobile/Documents/DarkSword-Workspace/AdaptiveInstall')
artifact = root / 'Dopamine-iPad5-DarkSword-adaptive.zip'
stage = root / 'artifact'
ipa = stage / 'Dopamine-iPad5-DarkSword-adaptive.ipa'

root.mkdir(parents=True, exist_ok=True)
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir(parents=True)

print('download=starting', flush=True)
req = urllib.request.Request(url, headers={'User-Agent':'NightVibes33-iPad6,11-installer'})
with urllib.request.urlopen(req, timeout=120) as response, artifact.open('wb') as out:
    shutil.copyfileobj(response, out, length=1024 * 1024)
print(f'artifact_bytes={artifact.stat().st_size}', flush=True)

with zipfile.ZipFile(artifact) as z:
    z.extractall(stage)
if not ipa.is_file():
    raise SystemExit('install_error=ipa-missing-in-artifact')

h = hashlib.sha256()
with ipa.open('rb') as f:
    for block in iter(lambda: f.read(1024 * 1024), b''):
        h.update(block)
actual = h.hexdigest()
print(f'ipa_sha256={actual}', flush=True)
if actual != expected_ipa_sha:
    raise SystemExit('install_error=ipa-checksum-mismatch')

manifest = (stage / 'adaptive-manifest.txt').read_text(errors='replace')
if f'source_sha={expected_source_sha}' not in manifest:
    raise SystemExit('install_error=manifest-source-mismatch')
if 'profile=adaptive-lowmem-v1' not in manifest:
    raise SystemExit('install_error=manifest-profile-mismatch')
print('artifact_verification=success', flush=True)

with zipfile.ZipFile(ipa) as z:
    info = plistlib.loads(z.read('Payload/Dopamine.app/Info.plist'))
    names = z.namelist()
    framework_path = 'Payload/Dopamine.app/Frameworks/DarkSword.framework/DarkSword'
    if framework_path not in names:
        raise SystemExit('install_error=darksword-framework-missing')
    framework = z.read(framework_path)

print('bundle_id=' + str(info.get('CFBundleIdentifier')), flush=True)
print('bundle_version=' + str(info.get('CFBundleShortVersionString')), flush=True)
print('minimum_os=' + str(info.get('MinimumOSVersion')), flush=True)
if info.get('CFBundleIdentifier') != 'com.opa334.Dopamine':
    raise SystemExit('install_error=unexpected-bundle-id')
for marker in (b'balanced-512MB', b'compact-384MB', b'minimum-256MB', b'DarkSword-iPad5-Adaptive.log'):
    if marker not in framework:
        raise SystemExit('install_error=adaptive-marker-missing:' + marker.decode())
print('embedded_adaptive_markers=success', flush=True)

candidates = []
for name in ('trollstorehelper', 'appinst'):
    found = shutil.which(name)
    if found:
        candidates.append(Path(found))
for fixed in (
    '/usr/local/bin/trollstorehelper',
    '/var/jb/usr/local/bin/trollstorehelper',
    '/var/jb/usr/bin/trollstorehelper',
    '/var/jb/usr/bin/appinst',
    '/usr/bin/appinst',
):
    p = Path(fixed)
    if p.is_file() and p not in candidates:
        candidates.append(p)
for base in (Path('/var/containers/Bundle/Application'), Path('/private/var/containers/Bundle/Application')):
    if base.is_dir():
        for p in base.glob('*/TrollStore.app/trollstorehelper'):
            if p.is_file() and p not in candidates:
                candidates.append(p)

print('installer_candidates=' + ','.join(str(p) for p in candidates), flush=True)
if not candidates:
    print('install_result=staged-no-installer-found', flush=True)
    print('staged_ipa=' + str(ipa), flush=True)
    raise SystemExit(0)

installer = candidates[0]
if installer.name == 'trollstorehelper':
    cmd = [str(installer), 'install', str(ipa)]
else:
    cmd = [str(installer), str(ipa)]
print('installer=' + str(installer), flush=True)
print('install_command=' + ' '.join(cmd[:2]) + ' [verified-ipa]', flush=True)
proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
print(proc.stdout[-4000:] if proc.stdout else '', flush=True)
print(f'installer_exit_code={proc.returncode}', flush=True)
if proc.returncode != 0:
    raise SystemExit('install_error=installer-failed')

installed = []
for base in (Path('/var/containers/Bundle/Application'), Path('/private/var/containers/Bundle/Application')):
    if base.is_dir():
        installed.extend(base.glob('*/Dopamine.app'))
print('installed_paths=' + ','.join(str(p) for p in installed), flush=True)
if not installed:
    print('install_result=installer-success-app-path-not-yet-visible', flush=True)
else:
    print('install_result=success-not-launched', flush=True)
print('important=do-not-run-dopamine-while-paleramine-kernel-is-active', flush=True)
PY
