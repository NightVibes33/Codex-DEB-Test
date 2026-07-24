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

project = Path("apps/ios/project.yml")
if project.exists():
    s = project.read_text()
    # Preserve every target and dependency. Only lower iOS-family deployment
    # targets to the minimum that supports ActivityKit on the user's iPadOS.
    s = s.replace('iOS: "18.0"', f'iOS: "{IOS_MIN}"')
    s = s.replace('deploymentTarget: "18.0"', f'deploymentTarget: "{IOS_MIN}"')
    s = s.replace('IPHONEOS_DEPLOYMENT_TARGET: "18.0"', f'IPHONEOS_DEPLOYMENT_TARGET: "{IOS_MIN}"')
    s = s.replace('com.sigkitten.litter', DARKSWORD_BUNDLE)
    if 'PRODUCT_NAME: DarkSwordAI' not in s:
        marker = f'        PRODUCT_BUNDLE_IDENTIFIER: {DARKSWORD_BUNDLE}\n'
        s = s.replace(marker, marker + '        PRODUCT_NAME: DarkSwordAI\n', 1)
    project.write_text(s)

# Upstream integration verification and its unsigned-build workflow intentionally
# pin the LiveProcess identifier. Keep the same validation after rebranding by
# teaching both files the DarkSword-prefixed identifier.
for relative in (
    "tools/scripts/verify-kittystore-integration.sh",
    ".github/workflows/ios-unsigned-ipa.yml",
):
    path = Path(relative)
    if not path.exists():
        continue
    s = path.read_text()
    s = s.replace(ORIGINAL_LIVEPROCESS_BUNDLE, DARKSWORD_LIVEPROCESS_BUNDLE)
    s = s.replace(
        "emexDE LiveProcess extension bundle id is Litter-prefixed",
        "emexDE LiveProcess extension bundle id is DarkSword-prefixed",
    )
    s = s.replace(
        "emexDE private LiveProcess workflow bundle id is Litter-prefixed",
        "emexDE private LiveProcess workflow bundle id is DarkSword-prefixed",
    )
    path.write_text(s)

makefile = Path("Makefile")
if makefile.exists():
    s = makefile.read_text()
    s = s.replace('IOS_DEPLOYMENT_TARGET ?= 18.0', f'IOS_DEPLOYMENT_TARGET ?= {IOS_MIN}')
    makefile.write_text(s)

info = Path("apps/ios/Sources/Litter/Info.plist")
if info.exists():
    s = info.read_text()
    s = s.replace('com.sigkitten.litter', DARKSWORD_BUNDLE)
    s = s.replace('<string>litterauth</string>', '<string>darkswordauth</string>')
    s = s.replace('Litter uses', 'DarkSword AI uses')
    s = s.replace('Codex discovers', 'DarkSword AI discovers')
    info.write_text(s)

# Make DarkSwordRootView the product entry while preserving the complete Litter
# ContentView as the Chat/Codex engine embedded by DarkSwordRootView.
app_entry = Path("apps/ios/Sources/Litter/LitterApp.swift")
if app_entry.exists():
    s = app_entry.read_text()
    old = '''        WindowGroup {
            ContentView()
'''
    new = '''        WindowGroup {
            DarkSwordRootView()
'''
    if old in s:
        s = s.replace(old, new, 1)
    elif 'DarkSwordRootView()' not in s:
        raise SystemExit("error: could not locate Litter WindowGroup ContentView entry")
    app_entry.write_text(s)

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

# The Dynamic Island trailing control used the same iOS-17-only Button(intent:)
# initializer. Keep the icon on iOS 16 and make it interactive on iOS 17+.
voice_activity = Path("apps/ios/Sources/LitterLiveActivity/CodexVoiceCallLiveActivity.swift")
if voice_activity.exists():
    s = voice_activity.read_text()
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
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .accessibilityLabel("End voice session from the app")
                    }
                }
'''
    if old in s:
        s = s.replace(old, new)
    voice_activity.write_text(s)

# Integrate the rootless host runtime directly into the current advanced Litter
# source. This replaces the stale patch-based integration and is idempotent.
lib_rs = Path("shared/rust-bridge/codex-mobile-client/src/lib.rs")
if not lib_rs.exists():
    raise SystemExit("error: missing codex-mobile-client/src/lib.rs")
s = lib_rs.read_text()
if 'pub mod darksword_host_runtime;' not in s:
    marker = '''#[cfg(all(target_os = "ios", not(target_abi = "macabi")))]
pub mod ish_runtime;
'''
    addition = marker + '''
#[cfg(all(target_os = "ios", not(target_abi = "macabi")))]
pub mod darksword_host_runtime;
'''
    if marker not in s:
        raise SystemExit("error: could not locate ish_runtime module declaration")
    s = s.replace(marker, addition, 1)
lib_rs.write_text(s)

ish_runtime = Path("shared/rust-bridge/codex-mobile-client/src/ish_runtime.rs")
if not ish_runtime.exists():
    raise SystemExit("error: missing ish_runtime.rs")
s = ish_runtime.read_text()
if 'crate::darksword_host_runtime::is_available()' not in s:
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
        return crate::darksword_host_runtime::run_streaming(
            cmd,
            cwd,
            timeout_ms,
            &mut on_output,
        );
    }
    run_streaming_inner(cmd, cwd, timeout_ms, true, on_output)
}
'''
    if old not in s:
        raise SystemExit("error: could not locate current run_streaming implementation")
    s = s.replace(old, new, 1)
ish_runtime.write_text(s)

instructions = Path("shared/rust-bridge/codex-mobile-client/src/local_runtime_instructions.rs")
if not instructions.exists():
    raise SystemExit("error: missing local_runtime_instructions.rs")
s = instructions.read_text()
start_marker = 'pub(crate) const IOS_LOCAL_RUNTIME_DEVELOPER_INSTRUCTIONS: &str = r#"'
start = s.find(start_marker)
if start < 0:
    raise SystemExit("error: could not locate iOS runtime instruction constant")
end = s.find('"#;', start)
if end < 0:
    raise SystemExit("error: could not locate end of iOS runtime instruction constant")
end += 3
replacement = '''pub(crate) const IOS_LOCAL_RUNTIME_DEVELOPER_INSTRUCTIONS: &str = r#"You are running inside DarkSword AI's local ChatGPT/Codex runtime on a jailbroken iOS device.

When `/var/jb/var/run/darksword-rootd.sock` is available, the shell tool runs through a root-owned daemon on the real iOS host filesystem. When the daemon is unavailable, commands fall back to Litter's persistent iSH Alpine Linux fakefs.

- On the host runtime, use `/var/jb` for rootless jailbreak files and `/var/mobile` for user-owned projects, logs, experiments, and app data.
- Inspect files, crash reports, Git status, and diffs before making changes.
- Use the installed `darksword-crash-classify` and `darksword-poc-run` commands for bounded, reproducible authorized research.
- Preserve backups and verify every mutation.
- Device erasure, destructive storage commands, credential extraction, unattended persistence, reboot commands, and unattended kernel writes are blocked.
- If the host daemon is unavailable, work under `/root` in iSH, use POSIX `/bin/sh` and Alpine/BusyBox expectations, and use `apk` for fakefs packages.
- `/root/.codex` remains bridged to Litter's native Codex home, and `/mnt/apps` remains the app-provided document bridge."#;'''
s = s[:start] + replacement + s[end:]
instructions.write_text(s)
PY

# Native DarkSword product shell and research surfaces. XcodeGen already
# includes Sources/Litter recursively, so these become part of the real app.
mkdir -p apps/ios/Sources/Litter/DarkSword
cp "$SCRIPT_DIR/app/DarkSwordRootView.swift" \
  apps/ios/Sources/Litter/DarkSword/DarkSwordRootView.swift
cp "$SCRIPT_DIR/app/DarkSwordResearchViews.swift" \
  apps/ios/Sources/Litter/DarkSword/DarkSwordResearchViews.swift

# The IPA carries the same templates, schema, and read-only helper scripts as
# resources. The rootless DEB additionally installs executable system copies.
LAB_SOURCE="$SCRIPT_DIR/../jailbreak-lab"
LAB_RESOURCE="apps/ios/Sources/Litter/Resources/JailbreakLab"
test -d "$LAB_SOURCE"
rm -rf "$LAB_RESOURCE"
mkdir -p "$(dirname "$LAB_RESOURCE")"
cp -R "$LAB_SOURCE" "$LAB_RESOURCE"

mkdir -p shared/rust-bridge/codex-mobile-client/src
cp "$SCRIPT_DIR/rust/darksword_host_runtime.rs" \
  shared/rust-bridge/codex-mobile-client/src/darksword_host_runtime.rs

grep -q 'pub mod darksword_host_runtime;' shared/rust-bridge/codex-mobile-client/src/lib.rs
grep -q 'darksword_host_runtime::is_available' shared/rust-bridge/codex-mobile-client/src/ish_runtime.rs
grep -q 'darksword-rootd.sock' shared/rust-bridge/codex-mobile-client/src/local_runtime_instructions.rs
grep -q 'DarkSwordRootView()' apps/ios/Sources/Litter/LitterApp.swift
grep -q 'com.nightvibes.darkswordai.39A8Q3T3TR.liveprocess' apps/ios/project.yml
grep -q '#available(iOSApplicationExtension 17.0' apps/ios/Sources/LitterLiveActivity/CodexVoiceCallLiveActivity.swift
test -f apps/ios/Sources/Litter/DarkSword/DarkSwordRootView.swift
test -f apps/ios/Sources/Litter/DarkSword/DarkSwordResearchViews.swift
test -f apps/ios/Sources/Litter/Resources/JailbreakLab/schema/experiment.schema.json

echo "Exact DarkSword app architecture, full NightVibes Litter, iOS 16.1, jailbreak lab, and rootless host runtime applied to $TARGET."
