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
    (
      cd "$ROOT_DIR"
      env GITHUB_REPOSITORY="$release_repo" \
        tools/scripts/prepare-emexde-corecompiler-artifacts.sh
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
