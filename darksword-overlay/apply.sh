#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"

chmod +x "$SCRIPT_DIR/apply-core.sh"
"$SCRIPT_DIR/apply-core.sh" "$TARGET"

COMPATIBILITY_SOURCE="$SCRIPT_DIR/app/DarkSwordCompatibility.swift"
test -f "$COMPATIBILITY_SOURCE"

mkdir -p "$TARGET/apps/ios/Sources/Litter/DarkSword"
cp "$COMPATIBILITY_SOURCE" \
  "$TARGET/apps/ios/Sources/Litter/DarkSword/DarkSwordCompatibility.swift"

for source_root in \
  LitterLiveActivity \
  LitterWatch \
  LitterWatchComplications
do
  test -d "$TARGET/apps/ios/Sources/$source_root"
  cp "$COMPATIBILITY_SOURCE" \
    "$TARGET/apps/ios/Sources/$source_root/DarkSwordCompatibility.swift"
done

# Use Apple's iPhoneOS compiler only for the real iOS Cargo target. The upstream
# script previously exported IPHONEOS_DEPLOYMENT_TARGET globally before UniFFI
# generated host bindings, causing host aws-lc-sys to target iPhone with the
# macOS SDK.
IOS_CLANG_SOURCE="$SCRIPT_DIR/rust/ios-clang-wrapper.sh"
IOS_CLANGXX_SOURCE="$SCRIPT_DIR/rust/ios-clangxx-wrapper.sh"
test -f "$IOS_CLANG_SOURCE"
test -f "$IOS_CLANGXX_SOURCE"
cp "$IOS_CLANG_SOURCE" "$TARGET/apps/ios/scripts/ios-clang-wrapper.sh"
cp "$IOS_CLANGXX_SOURCE" "$TARGET/apps/ios/scripts/ios-clangxx-wrapper.sh"
chmod +x \
  "$TARGET/apps/ios/scripts/ios-clang-wrapper.sh" \
  "$TARGET/apps/ios/scripts/ios-clangxx-wrapper.sh"

python3 - "$TARGET" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
path = root / "apps/ios/scripts/build-rust.sh"
text = path.read_text()

if 'IOS_CLANG_WRAPPER="$SCRIPT_DIR/ios-clang-wrapper.sh"' not in text:
    marker = 'IOS_CLANGXX_WRAPPER="$SCRIPT_DIR/ios-clangxx-wrapper.sh"\n'
    if marker not in text:
        raise SystemExit("error: missing iOS clang++ wrapper declaration")
    text = text.replace(
        marker,
        'IOS_CLANG_WRAPPER="$SCRIPT_DIR/ios-clang-wrapper.sh"\n' + marker,
        1,
    )

# Target-specific compiler settings do not affect the host UniFFI build.
old_exports = '''export CXX_aarch64_apple_ios="$IOS_CLANGXX_WRAPPER"
export CXX_aarch64_apple_ios_sim="$IOS_CLANGXX_WRAPPER"
export CXX_aarch64_apple_ios_macabi="$IOS_CLANGXX_WRAPPER"
export CXX_x86_64_apple_ios_macabi="$IOS_CLANGXX_WRAPPER"
export IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
export MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
'''
new_exports = '''export CC_aarch64_apple_ios="$IOS_CLANG_WRAPPER"
export CXX_aarch64_apple_ios="$IOS_CLANGXX_WRAPPER"
export AR_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ar)"
export RANLIB_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ranlib)"
export CXX_aarch64_apple_ios_sim="$IOS_CLANGXX_WRAPPER"
export CXX_aarch64_apple_ios_macabi="$IOS_CLANGXX_WRAPPER"
export CXX_x86_64_apple_ios_macabi="$IOS_CLANGXX_WRAPPER"
export MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
'''
if old_exports in text:
    text = text.replace(old_exports, new_exports, 1)
else:
    # Idempotent repair for snapshots where only the global iPhone export remains.
    text = text.replace('export IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"\n', '')
    if 'export CC_aarch64_apple_ios="$IOS_CLANG_WRAPPER"' not in text:
        marker = 'export CXX_aarch64_apple_ios="$IOS_CLANGXX_WRAPPER"\n'
        text = text.replace(
            marker,
            'export CC_aarch64_apple_ios="$IOS_CLANG_WRAPPER"\n'
            + marker
            + 'export AR_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ar)"\n'
            + 'export RANLIB_aarch64_apple_ios="$(xcrun --sdk iphoneos --find ranlib)"\n',
            1,
        )

# Supply the deployment target only to iOS/macabi Cargo invocations. Host Cargo
# commands used for UniFFI generation must never inherit this variable.
pattern = re.compile(
    r'(?m)^(?P<indent>[ \t]*)(?P<command>cargo rustc .*?--target '
    r'(?:aarch64|x86_64)-apple-ios(?:-sim|-macabi)?\b[^\n]*)$'
)

def scope_target(match: re.Match[str]) -> str:
    command = match.group('command')
    if command.startswith('env IPHONEOS_DEPLOYMENT_TARGET='):
        return match.group(0)
    return (
        match.group('indent')
        + 'env IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" '
        + command
    )

text = pattern.sub(scope_target, text)
path.write_text(text)
PY

chmod +x "$SCRIPT_DIR/backport_perception.py"
python3 "$SCRIPT_DIR/backport_perception.py" "$TARGET"

grep -q 'Perception:' "$TARGET/apps/ios/project.yml"
grep -q '@Perceptible' "$TARGET/apps/ios/Sources/Litter/Models/AppState.swift"
grep -q 'WithPerceptionTracking' "$TARGET/apps/ios/Sources/Litter/LitterApp.swift"
grep -q 'darkswordOnChange' "$TARGET/apps/ios/Sources/Litter/DarkSword/DarkSwordCompatibility.swift"
grep -q 'CC_aarch64_apple_ios="$IOS_CLANG_WRAPPER"' "$TARGET/apps/ios/scripts/build-rust.sh"
if grep -q '^export IPHONEOS_DEPLOYMENT_TARGET=' "$TARGET/apps/ios/scripts/build-rust.sh"; then
  echo 'error: global IPHONEOS_DEPLOYMENT_TARGET still present in build-rust.sh' >&2
  exit 1
fi
grep -q 'env IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" cargo rustc' \
  "$TARGET/apps/ios/scripts/build-rust.sh"

echo "DarkSword core overlay, iOS Rust toolchain isolation, and iOS 16 compatibility backports completed for $TARGET."
