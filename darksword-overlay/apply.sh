#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"
TARGET="$(cd "$TARGET" && pwd)"
cd "$TARGET"

python3 <<'PY'
from pathlib import Path

project = Path('apps/ios/project.yml')
if project.exists():
    s = project.read_text()
    s = s.replace('iOS: "18.0"', 'iOS: "16.0"')
    s = s.replace('IPHONEOS_DEPLOYMENT_TARGET: "18.0"', 'IPHONEOS_DEPLOYMENT_TARGET: "16.0"')
    s = s.replace('deploymentTarget: "18.0"', 'deploymentTarget: "16.0"')
    s = s.replace('com.sigkitten.litter', 'com.nightvibes.darkswordai')
    if 'PRODUCT_NAME: DarkSwordAI' not in s:
        marker = '        PRODUCT_BUNDLE_IDENTIFIER: com.nightvibes.darkswordai\n'
        s = s.replace(marker, marker + '        PRODUCT_NAME: DarkSwordAI\n', 1)

    # The jailbroken iPad package does not need Live Activities or a Watch app.
    # Removing them also avoids APIs requiring iOS 17+ while preserving the
    # full chat, model picker, OAuth, terminal, files, Git, and agent runtime.
    s = s.replace(
        '      - target: LitterLiveActivity\n        embed: true\n',
        '',
    )
    s = s.replace(
        '      - target: LitterWatch\n        embed: true\n',
        '',
    )
    s = s.replace(
        '      - path: Sources/LitterLiveActivity/CodexTurnLiveActivity.swift\n',
        '',
    )
    project.write_text(s)

info = Path('apps/ios/Sources/Litter/Info.plist')
if info.exists():
    s = info.read_text()
    s = s.replace('com.sigkitten.litter', 'com.nightvibes.darkswordai')
    s = s.replace('<string>litterauth</string>', '<string>darkswordauth</string>')
    s = s.replace('Litter uses', 'DarkSword AI uses')
    s = s.replace('Codex discovers', 'DarkSword AI discovers')
    info.write_text(s)

# Litter normally reads Codex's commit from a Git submodule gitlink. The source
# is vendored here, so preserve the explicitly restored SUBMODULES.lock commit.
sync = Path('apps/ios/scripts/sync-codex.sh')
if sync.exists():
    s = sync.read_text()
    old = '''    if [ -z "$recorded_commit" ]; then
        echo "error: could not resolve recorded submodule gitlink for shared/third_party/codex" >&2
        exit 1
    fi
'''
    new = '''    if [ -z "$recorded_commit" ]; then
        recorded_commit="$current_commit"
        echo "==> Vendored source: using pinned current codex checkout ${current_commit:0:9}"
    fi
'''
    s = s.replace(old, new)
    sync.write_text(s)
PY

mkdir -p shared/rust-bridge/codex-mobile-client/src
cp "$SCRIPT_DIR/rust/darksword_host_runtime.rs" \
  shared/rust-bridge/codex-mobile-client/src/darksword_host_runtime.rs

if ! grep -q 'pub mod darksword_host_runtime;' \
  shared/rust-bridge/codex-mobile-client/src/lib.rs; then
  patch -p1 < "$SCRIPT_DIR/patches/host-runtime.patch"
fi

echo "DarkSword iOS 16 and host-runtime overlay applied to $TARGET."
