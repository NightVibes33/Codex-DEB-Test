#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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
    project.write_text(s)

info = Path('apps/ios/Sources/Litter/Info.plist')
if info.exists():
    s = info.read_text()
    s = s.replace('com.sigkitten.litter', 'com.nightvibes.darkswordai')
    s = s.replace('<string>litterauth</string>', '<string>darkswordauth</string>')
    s = s.replace('Litter uses', 'DarkSword AI uses')
    s = s.replace('Codex discovers', 'DarkSword AI discovers')
    info.write_text(s)
PY

echo "DarkSword iOS 16 overlay applied."
