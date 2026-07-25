#!/bin/sh
set -eu
export PATH="/var/jb/usr/bin:/var/jb/usr/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
export HOME=/var/mobile

python3 <<'PY'
import os
import subprocess
from pathlib import Path

repo = Path('/var/mobile/Documents/DarkSword-Workspace/Dopamine')
branch = 'ipad5/adaptive-lowmem-v1'
ssh_key = Path('/var/mobile/.ssh/id_ed25519')
ssh_wrapper = Path('/var/mobile/.ssh/github-ipad-ssh')
workflow = repo / '.github/workflows/ipad5-adaptive-publish.yml'

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

def run(args):
    print('+', ' '.join(args), flush=True)
    p = subprocess.run(args, cwd=repo, env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if p.stdout:
        print(p.stdout.rstrip(), flush=True)
    if p.returncode != 0:
        raise SystemExit(f'publish_workflow_error={args[0]}:{p.returncode}')
    return p

run(['git', 'fetch', 'origin', branch])
run(['git', 'switch', branch])
run(['git', 'reset', '--hard', f'origin/{branch}'])
run(['git', 'config', 'user.name', 'NightVibes33 iPad'])
run(['git', 'config', 'user.email', 'NightVibes33@users.noreply.github.com'])

workflow.parent.mkdir(parents=True, exist_ok=True)
workflow.write_text(r'''name: "Dopamine: publish iPad 5 adaptive IPA"

on:
  push:
    branches:
      - ipad5/adaptive-lowmem-v1
    paths:
      - ".github/workflows/ipad5-adaptive-publish.yml"

permissions:
  actions: read
  contents: write

jobs:
  publish:
    name: Publish verified adaptive IPA
    runs-on: ubuntu-latest
    timeout-minutes: 15
    env:
      GH_TOKEN: ${{ github.token }}
      SOURCE_RUN_ID: "30151105627"
      ARTIFACT_ID: "8617729734"
      SOURCE_SHA: "020358a8549ab0a33482d3656b42ed3809fc515f"
      IPA_SHA256: "8cd2777ac994a6b56d401044ba8de0940d08b6fec847b3e0fae25ecac685250a"
      TAG: "ipad5-adaptive-v1-020358a"

    steps:
      - name: Checkout publisher branch
        uses: actions/checkout@v4
        with:
          ref: ipad5/adaptive-lowmem-v1
          fetch-depth: 0

      - name: Download exact successful artifact
        shell: bash
        run: |
          set -euo pipefail
          mkdir -p release
          gh api "/repos/${GITHUB_REPOSITORY}/actions/artifacts/${ARTIFACT_ID}/zip" > artifact.zip
          unzip -q artifact.zip -d release
          test -s release/Dopamine-iPad5-DarkSword-adaptive.ipa
          test -s release/adaptive-manifest.txt

      - name: Verify source and checksums
        shell: bash
        run: |
          set -euo pipefail
          actual="$(sha256sum release/Dopamine-iPad5-DarkSword-adaptive.ipa | awk '{print $1}')"
          test "$actual" = "$IPA_SHA256"
          grep -Fx "source_sha=${SOURCE_SHA}" release/adaptive-manifest.txt
          grep -Fx "workflow_run=${SOURCE_RUN_ID}" release/adaptive-manifest.txt
          grep -Fx "profile=adaptive-lowmem-v1" release/adaptive-manifest.txt
          printf '%s  %s\n' "$actual" 'Dopamine-iPad5-DarkSword-adaptive.ipa' > release/verified.sha256

      - name: Create or update prerelease
        shell: bash
        run: |
          set -euo pipefail
          if gh release view "$TAG" >/dev/null 2>&1; then
            gh release upload "$TAG" \
              release/Dopamine-iPad5-DarkSword-adaptive.ipa \
              release/Dopamine-iPad5-DarkSword-adaptive.ipa.sha256 \
              release/verified.sha256 \
              release/adaptive-manifest.txt \
              release/adaptive-dSYMs.tar.gz \
              --clobber
          else
            gh release create "$TAG" \
              --target "$SOURCE_SHA" \
              --prerelease \
              --title "iPad 5 DarkSword adaptive low-memory v1" \
              --notes "Experimental iPad6,11/iPad6,12 iOS 16.7.x build. Compile, package, source, and checksum gates passed. Stock-boot exploit success is not yet validated. IPA SHA-256: ${IPA_SHA256}." \
              release/Dopamine-iPad5-DarkSword-adaptive.ipa \
              release/Dopamine-iPad5-DarkSword-adaptive.ipa.sha256 \
              release/verified.sha256 \
              release/adaptive-manifest.txt \
              release/adaptive-dSYMs.tar.gz
          fi
          gh release view "$TAG" --json tagName,isPrerelease,targetCommitish,url
''')

run(['git', 'diff', '--check'])
run(['git', 'add', str(workflow.relative_to(repo))])
run(['git', 'commit', '-m', 'Add verified adaptive IPA prerelease publisher'])
head = run(['git', 'rev-parse', 'HEAD']).stdout.strip()
run(['git', 'push', 'origin', f'HEAD:{branch}'])
print(f'publisher_head={head}')
print('publisher_push=success')
PY
