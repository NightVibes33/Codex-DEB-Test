#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/Litter.xcodeproj"
NESTED_PROJECT="$PROJECT_FILE/Litter.xcodeproj"
REPAIR_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repair-only)
      REPAIR_ONLY=1
      shift
      ;;
    *)
      echo "usage: $(basename "$0") [--repair-only]" >&2
      exit 1
      ;;
  esac
done

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found; install xcodegen first" >&2
  exit 1
fi

# Full sideload builds include KittyStore/SideStore. Its Swift bridge sources
# and RustBridge.xcframework are generated artifacts, not ordinary Git files.
# Prepare them before XcodeGen so a clean CI checkout cannot reach the linker
# with a missing -lrust_bridge input.
if [[ "${LITTER_NYXIAN_PRIVATE_BUILD:-0}" == "1" ]]; then
  minimuxer_root="$ROOT_DIR/ThirdParty/SideStore"
  minimuxer_archive="$minimuxer_root/Source/Dependencies/minimuxer/RustBridge/lib/RustBridge.xcframework/ios-arm64/librust_bridge.a"
  minimuxer_device_lib="$ROOT_DIR/apps/ios/GeneratedRust/ios-device/libminimuxer-ios.a"
  minimuxer_swift="$ROOT_DIR/apps/ios/Sources/Litter/Generated/Minimuxer/minimuxer.generated.swift"

  if [[ ! -s "$minimuxer_archive" || ! -s "$minimuxer_device_lib" || ! -s "$minimuxer_swift" ]]; then
    echo "==> Building KittyStore minimuxer Rust bridge for full AlleyCat sideload build"
    if command -v brew >/dev/null 2>&1; then
      for formula in cmake pkgconf llvm; do
        brew list "$formula" >/dev/null 2>&1 || brew install "$formula"
      done
    fi
    (
      cd "$ROOT_DIR"
      tools/scripts/build-sidestore-minimuxer.sh
    )
  else
    echo "==> Using existing KittyStore minimuxer Rust bridge"
  fi

  test -s "$minimuxer_archive"
  test -s "$minimuxer_device_lib"
  test -s "$minimuxer_swift"
  grep -q 'startWithLogger' "$minimuxer_swift"
  grep -q 'installIpa' "$minimuxer_swift"
fi

# Full sideload builds intentionally include emexDE/CoreCompiler. Those binary
# support artifacts are release assets rather than normal Git source, so a
# clean GitHub runner must restore them before XcodeGen resolves CoreCompiler.
# Keep fast/release/TestFlight lanes unchanged.
if [[ "${LITTER_NYXIAN_PRIVATE_BUILD:-0}" == "1" ]]; then
  support_root="$ROOT_DIR/ThirdParty/EmexDE/Source/CoreCompiler/CoreCompilerSupportLibs"
  llvm_archive="$support_root/LLVM.xcframework/ios-arm64/llvm.a"
  swift_marker="$support_root/LLVM.xcframework/ios-arm64/Headers/swift/.emexde-swift-header-branch"
  support_dylib="$(find "$support_root" -maxdepth 1 -type f -name 'lib_Compiler*.dylib' -print -quit 2>/dev/null || true)"

  if [[ ! -s "$llvm_archive" || ! -s "$swift_marker" || -z "$support_dylib" ]]; then
    echo "==> Restoring emexDE CoreCompiler/LLVM assets for full AlleyCat sideload build"
    release_repo="${LITTER_EMEXDE_RELEASE_REPOSITORY:-NightVibes33/litter}"
    prepare_script="$ROOT_DIR/tools/scripts/prepare-emexde-corecompiler-artifacts.sh"

    # macOS still ships Bash 3.2. With `set -u`, expanding an empty array is
    # treated as an unbound variable. Keep the upstream authentication array
    # non-empty with a harmless header so public release downloads work even
    # when no token was exported into the shell environment.
    python3 - "$prepare_script" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = 'AUTH_HEADER=()\n'
new = 'AUTH_HEADER=(-H "User-Agent: AlleyCat-iOS-CI")\n'
if old in text:
    path.write_text(text.replace(old, new, 1))
elif new not in text:
    raise SystemExit('could not apply Bash 3.2 AUTH_HEADER compatibility patch')
PY

    (
      cd "$ROOT_DIR"
      env GITHUB_REPOSITORY="$release_repo" \
        "$prepare_script"
    )
  else
    echo "==> Using existing emexDE CoreCompiler/LLVM assets"
  fi

  test -s "$llvm_archive"
  test -s "$swift_marker"
  find "$support_root" -maxdepth 1 -type f -name 'lib_Compiler*.dylib' -print -quit | grep -q .

  (
    cd "$ROOT_DIR"
    python3 tools/scripts/patch-emexde-generated-swift-imports-for-ios-ci.py
    python3 tools/scripts/patch-emexde-corecompiler-for-ios-ci.py
  )
fi

needs_regen=0

if [[ -d "$NESTED_PROJECT" ]]; then
  echo "warning: found nested generated project at $NESTED_PROJECT" >&2
  echo "warning: removing nested generated project" >&2
  rm -rf "$NESTED_PROJECT"
  needs_regen=1
fi

if [[ ! -f "$PROJECT_FILE/project.pbxproj" ]]; then
  needs_regen=1
fi

if [[ "$REPAIR_ONLY" -eq 1 && "$needs_regen" -eq 0 ]]; then
  exit 0
fi

echo "==> Regenerating $PROJECT_FILE"
(
  cd "$PROJECT_DIR"
  xcodegen generate --spec project.yml
)

if [[ -d "$NESTED_PROJECT" ]]; then
  echo "error: nested project still exists at $NESTED_PROJECT" >&2
  exit 1
fi

# Fix StoreKit Configuration in scheme — xcodegen doesn't generate a valid reference.
SCHEME_FILE="$PROJECT_FILE/xcshareddata/xcschemes/Litter.xcscheme"
if [[ -f "$SCHEME_FILE" ]]; then
  # Remove broken xcodegen-generated StoreKitConfigurationFileReference if present
  sed -i '' '/<StoreKitConfigurationFileReference/,/<\/StoreKitConfigurationFileReference>/d' "$SCHEME_FILE"
  # Insert correct one before </LaunchAction>
  sed -i '' 's|</LaunchAction>|      <StoreKitConfigurationFileReference\
         identifier = "../../Sources/Litter/Resources/TipJarProducts.storekit">\
       </StoreKitConfigurationFileReference>\
    </LaunchAction>|' "$SCHEME_FILE"
fi
