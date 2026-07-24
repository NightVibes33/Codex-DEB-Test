#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"

chmod +x "$SCRIPT_DIR/apply-core.sh"
"$SCRIPT_DIR/apply-core.sh" "$TARGET"

COMPATIBILITY_SOURCE="$SCRIPT_DIR/app/DarkSwordCompatibility.swift"
LABS_VIEW_SOURCE="$SCRIPT_DIR/app/AlleyCatLabsView.swift"
test -f "$COMPATIBILITY_SOURCE"
test -f "$LABS_VIEW_SOURCE"

mkdir -p "$TARGET/apps/ios/Sources/Litter/DarkSword"
cp "$COMPATIBILITY_SOURCE" \
  "$TARGET/apps/ios/Sources/Litter/DarkSword/DarkSwordCompatibility.swift"
cp "$LABS_VIEW_SOURCE" \
  "$TARGET/apps/ios/Sources/Litter/DarkSword/AlleyCatLabsView.swift"

for source_root in \
  LitterLiveActivity \
  LitterWatch \
  LitterWatchComplications
do
  test -d "$TARGET/apps/ios/Sources/$source_root"
  cp "$COMPATIBILITY_SOURCE" \
    "$TARGET/apps/ios/Sources/$source_root/DarkSwordCompatibility.swift"
done

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

chmod +x "$SCRIPT_DIR/restore_alleycat_ui.py"
python3 "$SCRIPT_DIR/restore_alleycat_ui.py" "$TARGET"

chmod +x "$SCRIPT_DIR/backport_perception.py"
python3 "$SCRIPT_DIR/backport_perception.py" "$TARGET"

require_grep() {
  local label="$1"
  local pattern="$2"
  local file="$3"
  if ! grep -q -- "$pattern" "$file"; then
    echo "error: AlleyCat overlay verification failed: $label ($file)" >&2
    exit 1
  fi
  echo "verified: $label"
}

require_grep "Perception package" 'Perception:' "$TARGET/apps/ios/project.yml"
require_grep "Perceptible AppState" '@Perceptible' "$TARGET/apps/ios/Sources/Litter/Models/AppState.swift"
require_grep "iOS 16 onChange compatibility" 'darkswordOnChange' "$TARGET/apps/ios/Sources/Litter/DarkSword/DarkSwordCompatibility.swift"
require_grep "iPhone C compiler wrapper" 'CC_aarch64_apple_ios="$IOS_CLANG_WRAPPER"' "$TARGET/apps/ios/scripts/build-rust.sh"
require_grep "real AlleyCat root" 'ContentView()' "$TARGET/apps/ios/Sources/Litter/LitterApp.swift"
require_grep "AlleyCat Labs settings entry" 'AlleyCat Labs' "$TARGET/apps/ios/Sources/Litter/Views/SettingsView.swift"
require_grep "AlleyCat product name" 'PRODUCT_NAME: AlleyCat' "$TARGET/apps/ios/project.yml"
require_grep "Alley Cãt display name" '<string>Alley Cãt</string>' "$TARGET/apps/ios/Sources/Litter/Info.plist"
require_grep "target-scoped iPhone deployment" 'env IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" cargo rustc' "$TARGET/apps/ios/scripts/build-rust.sh"

if grep -q 'DarkSwordRootView()' "$TARGET/apps/ios/Sources/Litter/LitterApp.swift"; then
  echo 'error: replacement DarkSword tab shell is still the app root' >&2
  exit 1
fi
if grep -q '^export IPHONEOS_DEPLOYMENT_TARGET=' "$TARGET/apps/ios/scripts/build-rust.sh"; then
  echo 'error: global IPHONEOS_DEPLOYMENT_TARGET still present in build-rust.sh' >&2
  exit 1
fi

echo "Full AlleyCat UI, rootless host tools, iOS Rust isolation, and iOS 16 compatibility backports completed for $TARGET."
