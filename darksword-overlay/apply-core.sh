#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"
TARGET="$(cd "$TARGET" && pwd)"
cd "$TARGET"

python3 <<'PY'
from pathlib import Path

IOS_MIN = "16.1"
DARKSWORD_BUNDLE = "com.nightvibes.darkswordai"
ORIGINAL_LIVEPROCESS_BUNDLE = "com.sigkitten.litter.39A8Q3T3TR.liveprocess"
DARKSWORD_LIVEPROCESS_BUNDLE = f"{DARKSWORD_BUNDLE}.39A8Q3T3TR.liveprocess"


def read(path: str) -> tuple[Path, str] | tuple[None, None]:
    file = Path(path)
    if not file.exists():
        return None, None
    return file, file.read_text()


# Lower deployment targets and rebrand the main app plus embedded targets.
project, text = read("apps/ios/project.yml")
if project:
    text = text.replace('iOS: "18.0"', f'iOS: "{IOS_MIN}"')
    text = text.replace('deploymentTarget: "18.0"', f'deploymentTarget: "{IOS_MIN}"')
    text = text.replace('IPHONEOS_DEPLOYMENT_TARGET: "18.0"', f'IPHONEOS_DEPLOYMENT_TARGET: "{IOS_MIN}"')
    text = text.replace('com.sigkitten.litter', DARKSWORD_BUNDLE)
    marker = f'        PRODUCT_BUNDLE_IDENTIFIER: {DARKSWORD_BUNDLE}\n'
    if 'PRODUCT_NAME: DarkSwordAI' not in text and marker in text:
        text = text.replace(marker, marker + '        PRODUCT_NAME: DarkSwordAI\n', 1)
    project.write_text(text)

# Keep upstream verification meaningful after the intentional bundle-ID rename.
for relative in (
    "tools/scripts/verify-kittystore-integration.sh",
    ".github/workflows/ios-unsigned-ipa.yml",
):
    path, text = read(relative)
    if not path:
        continue
    text = text.replace(ORIGINAL_LIVEPROCESS_BUNDLE, DARKSWORD_LIVEPROCESS_BUNDLE)
    text = text.replace(
        "emexDE LiveProcess extension bundle id is Litter-prefixed",
        "emexDE LiveProcess extension bundle id is DarkSword-prefixed",
    )
    text = text.replace(
        "emexDE private LiveProcess workflow bundle id is Litter-prefixed",
        "emexDE private LiveProcess workflow bundle id is DarkSword-prefixed",
    )
    path.write_text(text)

makefile, text = read("Makefile")
if makefile:
    makefile.write_text(text.replace('IOS_DEPLOYMENT_TARGET ?= 18.0', f'IOS_DEPLOYMENT_TARGET ?= {IOS_MIN}'))

info, text = read("apps/ios/Sources/Litter/Info.plist")
if info:
    text = text.replace('com.sigkitten.litter', DARKSWORD_BUNDLE)
    text = text.replace('<string>litterauth</string>', '<string>darkswordauth</string>')
    text = text.replace('Litter uses', 'DarkSword AI uses')
    text = text.replace('Codex discovers', 'DarkSword AI discovers')
    info.write_text(text)

# Launch the DarkSword shell while preserving the full Litter ContentView engine.
app_entry, text = read("apps/ios/Sources/Litter/LitterApp.swift")
if app_entry:
    old = """        WindowGroup {
            ContentView()
"""
    new = """        WindowGroup {
            DarkSwordRootView()
"""
    if old in text:
        text = text.replace(old, new, 1)
    elif "DarkSwordRootView()" not in text:
        raise SystemExit("error: could not locate Litter WindowGroup ContentView entry")
    app_entry.write_text(text)

# Vendored snapshots have no gitlink metadata. Use the restored checkout itself.
for relative, label in (
    ("apps/ios/scripts/sync-codex.sh", "codex"),
    ("apps/ios/scripts/sync-ghostty.sh", "ghostty"),
):
    path, text = read(relative)
    if not path:
        continue
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
    path.write_text(text.replace(old, new))

# Ghostty requires Zig 0.15.2. Homebrew currently supplies a newer incompatible
# release, so the builder downloads the official pinned toolchain when needed.
ghostty_builder, text = read("apps/ios/scripts/build-ghostty.sh")
if not ghostty_builder:
    raise SystemExit("error: missing Ghostty iOS builder")
if 'REQUIRED_ZIG_VERSION="0.15.2"' not in text:
    old = '''if ! command -v zig >/dev/null 2>&1; then
    echo "error: zig is required to build Ghostty (brew install zig)" >&2
    exit 1
fi
'''
    new = '''REQUIRED_ZIG_VERSION="0.15.2"
ensure_required_zig() {
    local current=""
    local host_arch zig_arch archive url cache_root install_dir unpacked_dir
    if command -v zig >/dev/null 2>&1; then
        current="$(zig version 2>/dev/null || true)"
    fi
    if [ "$current" = "$REQUIRED_ZIG_VERSION" ]; then
        return
    fi
    host_arch="$(uname -m)"
    case "$host_arch" in
        arm64|aarch64) zig_arch="aarch64" ;;
        x86_64|amd64) zig_arch="x86_64" ;;
        *) echo "error: unsupported macOS architecture for Zig: $host_arch" >&2; exit 1 ;;
    esac
    cache_root="${GHOSTTY_ZIG_TOOLCHAIN_ROOT:-$HOME/.cache/darksword-zig}"
    install_dir="$cache_root/$REQUIRED_ZIG_VERSION-$zig_arch-macos"
    if [ ! -x "$install_dir/zig" ]; then
        archive="zig-$zig_arch-macos-$REQUIRED_ZIG_VERSION.tar.xz"
        url="https://ziglang.org/download/$REQUIRED_ZIG_VERSION/$archive"
        unpacked_dir="zig-$zig_arch-macos-$REQUIRED_ZIG_VERSION"
        mkdir -p "$cache_root"
        rm -rf "$install_dir" "$cache_root/$unpacked_dir"
        echo "==> Installing Zig $REQUIRED_ZIG_VERSION from $url..."
        curl --fail --location --retry 4 --retry-delay 2 "$url" -o "$cache_root/$archive"
        tar -xJf "$cache_root/$archive" -C "$cache_root"
        mv "$cache_root/$unpacked_dir" "$install_dir"
        rm -f "$cache_root/$archive"
    fi
    export PATH="$install_dir:$PATH"
    current="$(zig version)"
    if [ "$current" != "$REQUIRED_ZIG_VERSION" ]; then
        echo "error: Ghostty requires Zig $REQUIRED_ZIG_VERSION, resolved $current" >&2
        exit 1
    fi
    echo "==> Using Zig $current from $(command -v zig)"
}
ensure_required_zig
'''
    if old not in text:
        raise SystemExit("error: could not locate Ghostty Zig preflight")
    text = text.replace(old, new, 1)
text = text.replace('"aarch64-ios.18.0"', f'"aarch64-ios.{IOS_MIN}"')
text = text.replace('"aarch64-ios.18.0-simulator"', f'"aarch64-ios.{IOS_MIN}-simulator"')
text = text.replace('"aarch64-ios.18.0-macabi"', f'"aarch64-ios.{IOS_MIN}-macabi"')
ghostty_builder.write_text(text)

# Back-deploy iOS-17-only AppIntent buttons while retaining interaction on 17+.
voice_card, text = read("apps/ios/Sources/LitterLiveActivity/VoiceCallLockScreenCardView.swift")
if voice_card:
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
                    Button(intent: EndVoiceSessionIntent()) { endSessionIcon }
                        .buttonStyle(.plain)
                } else {
                    endSessionIcon.accessibilityLabel("End voice session from the app")
                }
'''
    text = text.replace(old, new)
    if 'private var endSessionIcon: some View' not in text:
        marker = '    private var statusText: String {'
        helper = '''    private var endSessionIcon: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(8)
            .background(Circle().fill(LitterPalette.danger.color(for: colorScheme)))
    }

'''
        text = text.replace(marker, helper + marker)
    voice_card.write_text(text)

voice_activity, text = read("apps/ios/Sources/LitterLiveActivity/CodexVoiceCallLiveActivity.swift")
if voice_activity:
    old = '''                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: EndVoiceSessionIntent()) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
'''
    new = '''                DynamicIslandExpandedRegion(.trailing) {
                    if #available(iOSApplicationExtension 17.0, *) {
                        Button(intent: EndVoiceSessionIntent()) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .accessibilityLabel("End voice session from the app")
                    }
                }
'''
    voice_activity.write_text(text.replace(old, new))

# Route Litter's local shell tool through the rootless host daemon when present.
lib_rs, text = read("shared/rust-bridge/codex-mobile-client/src/lib.rs")
if not lib_rs:
    raise SystemExit("error: missing codex-mobile-client/src/lib.rs")
if 'pub mod darksword_host_runtime;' not in text:
    marker = '''#[cfg(all(target_os = "ios", not(target_abi = "macabi")))]
pub mod ish_runtime;
'''
    addition = marker + '''
#[cfg(all(target_os = "ios", not(target_abi = "macabi")))]
pub mod darksword_host_runtime;
'''
    if marker not in text:
        raise SystemExit("error: could not locate ish_runtime module declaration")
    text = text.replace(marker, addition, 1)
lib_rs.write_text(text)

ish_runtime, text = read("shared/rust-bridge/codex-mobile-client/src/ish_runtime.rs")
if not ish_runtime:
    raise SystemExit("error: missing ish_runtime.rs")
if 'crate::darksword_host_runtime::is_available()' not in text:
    old = '''pub fn run_streaming<F>(
    cmd: &str,
    cwd: Option<&str>,
    timeout_ms: Option<u64>,
    on_output: F,
) -> (i32, Vec<u8>)
where
    F: FnMut(&[u8]),
{
    run_streaming_inner(cmd, cwd, timeout_ms, true, on_output)
}
'''
    new = '''pub fn run_streaming<F>(
    cmd: &str,
    cwd: Option<&str>,
    timeout_ms: Option<u64>,
    mut on_output: F,
) -> (i32, Vec<u8>)
where
    F: FnMut(&[u8]),
{
    if crate::darksword_host_runtime::is_available() {
        return crate::darksword_host_runtime::run_streaming(cmd, cwd, timeout_ms, &mut on_output);
    }
    run_streaming_inner(cmd, cwd, timeout_ms, true, on_output)
}
'''
    if old not in text:
        raise SystemExit("error: could not locate current run_streaming implementation")
    text = text.replace(old, new, 1)
ish_runtime.write_text(text)

instructions, text = read("shared/rust-bridge/codex-mobile-client/src/local_runtime_instructions.rs")
if not instructions:
    raise SystemExit("error: missing local_runtime_instructions.rs")
start_marker = 'pub(crate) const IOS_LOCAL_RUNTIME_DEVELOPER_INSTRUCTIONS: &str = r#"'
start = text.find(start_marker)
end = text.find('"#;', start)
if start < 0 or end < 0:
    raise SystemExit("error: could not locate iOS runtime instruction constant")
end += 3
replacement = '''pub(crate) const IOS_LOCAL_RUNTIME_DEVELOPER_INSTRUCTIONS: &str = r#"You are running inside DarkSword AI's local ChatGPT/Codex runtime on a jailbroken iOS device.

When `/var/jb/var/run/darksword-rootd.sock` is available, the shell tool runs through a root-owned daemon on the real iOS host filesystem. When the daemon is unavailable, commands fall back to Litter's persistent iSH Alpine Linux fakefs.

- Use `/var/jb` for rootless jailbreak files and `/var/mobile` for projects, logs, and experiments.
- Inspect files, crash reports, Git status, and diffs before changing them.
- Use `darksword-crash-classify` and `darksword-poc-run` for bounded authorized research.
- Preserve backups and verify mutations.
- Device erasure, destructive storage commands, credential extraction, unattended persistence, reboot commands, and unattended kernel writes are blocked.
- In iSH fallback mode, work under `/root`, use POSIX `/bin/sh`, Alpine/BusyBox tools, and `apk`.
- `/root/.codex` remains bridged to Litter's native Codex home and `/mnt/apps` remains the document bridge."#;'''
instructions.write_text(text[:start] + replacement + text[end:])
PY

mkdir -p apps/ios/Sources/Litter/DarkSword
cp "$SCRIPT_DIR/app/DarkSwordRootView.swift" apps/ios/Sources/Litter/DarkSword/DarkSwordRootView.swift
cp "$SCRIPT_DIR/app/DarkSwordResearchViews.swift" apps/ios/Sources/Litter/DarkSword/DarkSwordResearchViews.swift

LAB_SOURCE="$SCRIPT_DIR/../jailbreak-lab"
LAB_RESOURCE="apps/ios/Sources/Litter/Resources/JailbreakLab"
test -d "$LAB_SOURCE"
rm -rf "$LAB_RESOURCE"
mkdir -p "$(dirname "$LAB_RESOURCE")"
cp -R "$LAB_SOURCE" "$LAB_RESOURCE"

mkdir -p shared/rust-bridge/codex-mobile-client/src
cp "$SCRIPT_DIR/rust/darksword_host_runtime.rs" shared/rust-bridge/codex-mobile-client/src/darksword_host_runtime.rs

grep -q 'pub mod darksword_host_runtime;' shared/rust-bridge/codex-mobile-client/src/lib.rs
grep -q 'darksword_host_runtime::is_available' shared/rust-bridge/codex-mobile-client/src/ish_runtime.rs
grep -q 'darksword-rootd.sock' shared/rust-bridge/codex-mobile-client/src/local_runtime_instructions.rs
grep -q 'DarkSwordRootView()' apps/ios/Sources/Litter/LitterApp.swift
grep -q 'com.nightvibes.darkswordai.39A8Q3T3TR.liveprocess' apps/ios/project.yml
grep -q 'REQUIRED_ZIG_VERSION="0.15.2"' apps/ios/scripts/build-ghostty.sh
grep -q 'aarch64-ios.16.1' apps/ios/scripts/build-ghostty.sh
grep -q '#available(iOSApplicationExtension 17.0' apps/ios/Sources/LitterLiveActivity/CodexVoiceCallLiveActivity.swift
test -f apps/ios/Sources/Litter/DarkSword/DarkSwordRootView.swift
test -f apps/ios/Sources/Litter/DarkSword/DarkSwordResearchViews.swift
test -f apps/ios/Sources/Litter/Resources/JailbreakLab/schema/experiment.schema.json

echo "Exact DarkSword app architecture, full NightVibes Litter, iOS 16.1, pinned Zig, jailbreak lab, and rootless host runtime applied to $TARGET."
