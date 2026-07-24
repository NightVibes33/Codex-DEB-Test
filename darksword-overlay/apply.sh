#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"
TARGET="$(cd "$TARGET" && pwd)"
cd "$TARGET"

python3 <<'PY'
from pathlib import Path

IOS_MIN = "16.1"

project = Path("apps/ios/project.yml")
if project.exists():
    s = project.read_text()
    # Preserve every target and dependency. Only lower iOS-family deployment
    # targets to the minimum that supports ActivityKit on the user's iPadOS.
    s = s.replace('iOS: "18.0"', f'iOS: "{IOS_MIN}"')
    s = s.replace('deploymentTarget: "18.0"', f'deploymentTarget: "{IOS_MIN}"')
    s = s.replace('IPHONEOS_DEPLOYMENT_TARGET: "18.0"', f'IPHONEOS_DEPLOYMENT_TARGET: "{IOS_MIN}"')
    s = s.replace('com.sigkitten.litter', 'com.nightvibes.darkswordai')
    if 'PRODUCT_NAME: DarkSwordAI' not in s:
        marker = '        PRODUCT_BUNDLE_IDENTIFIER: com.nightvibes.darkswordai\n'
        s = s.replace(marker, marker + '        PRODUCT_NAME: DarkSwordAI\n', 1)
    project.write_text(s)

makefile = Path("Makefile")
if makefile.exists():
    s = makefile.read_text()
    s = s.replace('IOS_DEPLOYMENT_TARGET ?= 18.0', f'IOS_DEPLOYMENT_TARGET ?= {IOS_MIN}')
    makefile.write_text(s)

info = Path("apps/ios/Sources/Litter/Info.plist")
if info.exists():
    s = info.read_text()
    s = s.replace('com.sigkitten.litter', 'com.nightvibes.darkswordai')
    s = s.replace('<string>litterauth</string>', '<string>darkswordauth</string>')
    s = s.replace('Litter uses', 'DarkSword AI uses')
    s = s.replace('Codex discovers', 'DarkSword AI discovers')
    info.write_text(s)

# Vendored source does not retain gitlink metadata after rsync. Preserve the
# exact restored checkout instead of aborting Codex/Ghostty patch application.
for relative, label in (
    ("apps/ios/scripts/sync-codex.sh", "codex"),
    ("apps/ios/scripts/sync-ghostty.sh", "ghostty"),
):
    path = Path(relative)
    if not path.exists():
        continue
    s = path.read_text()
    old = f'''    if [ -z "$recorded_commit" ]; then
        echo "error: could not resolve recorded submodule gitlink for shared/third_party/{label}" >&2
        exit 1
    fi
'''
    new = f'''    if [ -z "$recorded_commit" ]; then
        recorded_commit="$current_commit"
        echo "==> Vendored source: using pinned current {label} checkout ${{current_commit:0:9}}"
    fi
'''
    s = s.replace(old, new)
    path.write_text(s)

# Keep the complete Live Activity target. On iOS 16.1-16.7 the AppIntent-backed
# button API does not exist, so retain the visual control and enable the real
# interactive intent automatically on iOS 17+.
voice_card = Path("apps/ios/Sources/LitterLiveActivity/VoiceCallLockScreenCardView.swift")
if voice_card.exists():
    s = voice_card.read_text()
    old = '''                Button(intent: EndVoiceSessionIntent()) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(LitterPalette.danger.color(for: colorScheme)))
                }
                .buttonStyle(.plain)
'''
    new = '''                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: EndVoiceSessionIntent()) {
                        endSessionIcon
                    }
                    .buttonStyle(.plain)
                } else {
                    endSessionIcon
                        .accessibilityLabel("End voice session from the app")
                }
'''
    if old in s:
        s = s.replace(old, new)
    if 'private var endSessionIcon: some View' not in s:
        marker = '    private var statusText: String {'
        helper = '''    private var endSessionIcon: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(8)
            .background(Circle().fill(LitterPalette.danger.color(for: colorScheme)))
    }

'''
        s = s.replace(marker, helper + marker)
    voice_card.write_text(s)
PY

mkdir -p shared/rust-bridge/codex-mobile-client/src
cp "$SCRIPT_DIR/rust/darksword_host_runtime.rs" \
  shared/rust-bridge/codex-mobile-client/src/darksword_host_runtime.rs

if ! grep -q 'pub mod darksword_host_runtime;' \
  shared/rust-bridge/codex-mobile-client/src/lib.rs; then
  patch -p1 < "$SCRIPT_DIR/patches/host-runtime.patch"
fi

echo "Full NightVibes Litter preserved; iOS 16.1 and rootless host-runtime overlay applied to $TARGET."
