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
      # The vendored libimobiledevice stack is bootstrapped from configure.ac
      # during Cargo builds. gettext provides autopoint; Homebrew keeps its bin
      # directory keg-only, so add it explicitly for the bootstrap scripts.
      for formula in autoconf automake libtool gettext cmake pkgconf llvm; do
        brew list "$formula" >/dev/null 2>&1 || brew install "$formula"
      done
      export PATH="$(brew --prefix gettext)/bin:$PATH"
    fi

    # SideStore's rusty_libimobiledevice build script assumes openssl-src always
    # installs headers into one canonical directory and silently ignores failed
    # autogen.sh runs. Both assumptions are false on clean macOS/Xcode runners.
    # Patch the checked-out source deterministically before Cargo evaluates it.
    rusty_build="$ROOT_DIR/ThirdParty/SideStore/rusty_libimobiledevice/build.rs"
    python3 - "$rusty_build" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

old_openssl = '''                        include_path = format!(
                            "{} -I{}",
                            include_path,
                            install_path
                                .join("include")
                                .canonicalize()
                                .unwrap()
                                .display()
                        );
'''
new_openssl = '''                        let openssl_build_root = path.join("out").join("openssl-build");
                        let include_candidates = [
                            install_path.join("include"),
                            openssl_build_root.join("build").join("src").join("include"),
                            openssl_build_root
                                .join("build")
                                .join("src")
                                .join("build")
                                .join("include"),
                            openssl_build_root.join("build").join("include"),
                        ];
                        let mut openssl_include_found = false;
                        for candidate in include_candidates {
                            if candidate.is_dir() {
                                include_path =
                                    format!("{} -I{}", include_path, candidate.display());
                                openssl_include_found = true;
                            }
                        }
                        assert!(
                            openssl_include_found,
                            "openssl-src headers were not found under {}",
                            openssl_build_root.display()
                        );
'''

old_repo_setup = '''fn repo_setup(url: &str) {
    let mut cmd = std::process::Command::new("git");
    cmd.arg("clone");
    cmd.arg("--depth=1");
    cmd.arg(url);
    cmd.output().unwrap();
    env::set_current_dir(url.split('/').last().unwrap().replace(".git", "")).unwrap();
    env::set_var("NOCONFIGURE", "1");
    let mut cmd = std::process::Command::new("./autogen.sh");
    let _ = cmd.output();
    env::remove_var("NOCONFIGURE");
    env::set_current_dir("..").unwrap();
}
'''
new_repo_setup = '''fn repo_setup(url: &str) {
    let repo_name = url.split('/').last().unwrap().replace(".git", "");

    let status = std::process::Command::new("git")
        .args(["clone", "--depth=1", url])
        .status()
        .expect("failed to launch git clone for vendored libimobiledevice dependency");
    assert!(status.success(), "failed to clone {url}");

    env::set_current_dir(&repo_name).unwrap();

    let mut bootstrap = std::process::Command::new("./autogen.sh");
    bootstrap.env("NOCONFIGURE", "1");
    if env::consts::OS == "macos" {
        bootstrap.env("LIBTOOLIZE", "glibtoolize");
    }
    let mut needs_fallback = match bootstrap.status() {
        Ok(status) => !status.success(),
        Err(_) => true,
    };
    if !needs_fallback {
        let configure_text = std::fs::read_to_string("configure").unwrap_or_default();
        needs_fallback = configure_text.is_empty()
            || configure_text.contains("AM_INIT_AUTOMAKE(");
    }
    if needs_fallback {
        let mut fallback = std::process::Command::new("autoreconf");
        fallback.args(["-fiv"]);
        if env::consts::OS == "macos" {
            fallback.env("LIBTOOLIZE", "glibtoolize");
        }
        let status = fallback
            .status()
            .expect("failed to launch autoreconf for vendored dependency");
        assert!(status.success(), "failed to bootstrap {repo_name}");
    }

    let configure_text = std::fs::read_to_string("configure")
        .expect("bootstrap did not produce a readable configure script");
    assert!(
        !configure_text.contains("AM_INIT_AUTOMAKE("),
        "configure script for {repo_name} still contains unexpanded Automake macros"
    );

    env::set_current_dir("..").unwrap();
}
'''

if old_openssl in text:
    text = text.replace(old_openssl, new_openssl, 1)
elif new_openssl not in text:
    raise SystemExit("could not patch rusty_libimobiledevice OpenSSL include discovery")

if old_repo_setup in text:
    text = text.replace(old_repo_setup, new_repo_setup, 1)
elif new_repo_setup not in text:
    raise SystemExit("could not patch rusty_libimobiledevice repo bootstrap")

path.write_text(text)
PY

    (
      cd "$ROOT_DIR"
      env \
        LITTER_MINIMUXER_MIN_IOS="${IOS_DEPLOYMENT_TARGET:-${IPHONEOS_DEPLOYMENT_TARGET:-16.1}}" \
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
