#!/usr/bin/env bash
set -euo pipefail

# This script runs from the root of the official openai/codex checkout.
# Keep source modifications minimal so the iOS port tracks upstream closely.

# Codex commit da616136 introduced the experimental code-mode/V8 dependency.
# rusty_v8 does not publish an aarch64-apple-ios archive, so pin the newest
# official revision immediately before that feature landed. Normal Codex OAuth,
# shell execution, file edits, MCP, and TUI operation remain available.
IOS_UPSTREAM_REF="da616136ccff31142b159e97da67705bf0ab7555^"
git checkout --detach "$IOS_UPSTREAM_REF"
git rev-parse HEAD | tee "$GITHUB_WORKSPACE/codex-ios-upstream-sha.txt"

# Confirm this really is the pre-V8 graph.
test -f codex-rs/Cargo.toml
test -f codex-rs/cli/src/main.rs
test -f codex-rs/login/src/device_code_auth.rs
test -f codex-rs/rust-toolchain.toml
grep -q 'device-auth' codex-rs/cli/src/main.rs
if grep -q 'codex-code-mode' codex-rs/core/Cargo.toml; then
  echo 'Unexpected V8 code-mode dependency remains in the pinned revision.' >&2
  exit 1
fi

# Apply the small platform cfg adaptations needed for an iOS Unix target.
python3 - <<'PY'
from pathlib import Path

# arboard is a desktop clipboard backend. On iOS it otherwise pulls Wayland/X11.
cargo = Path('codex-rs/tui/Cargo.toml')
text = cargo.read_text()
old = "[target.'cfg(not(target_os = \"android\"))'.dependencies]\narboard = { workspace = true }"
new = "[target.'cfg(not(any(target_os = \"android\", target_os = \"ios\")))'.dependencies]\narboard = { workspace = true }"
if old not in text:
    raise SystemExit('tui arboard dependency block changed upstream')
cargo.write_text(text.replace(old, new, 1))

paste = Path('codex-rs/tui/src/clipboard_paste.rs')
text = paste.read_text()
text = text.replace(
    '#[cfg(not(target_os = "android"))]',
    '#[cfg(not(any(target_os = "android", target_os = "ios")))]',
)
text = text.replace(
    '#[cfg(target_os = "android")]',
    '#[cfg(any(target_os = "android", target_os = "ios"))]',
)
text = text.replace('unsupported on Android', 'unsupported on this mobile platform')
paste.write_text(text)

copy = Path('codex-rs/tui/src/clipboard_copy.rs')
if copy.exists():
    text = copy.read_text()
    text = text.replace(
        '#[cfg(all(not(target_os = "android"), not(target_os = "linux")))]',
        '#[cfg(all(not(any(target_os = "android", target_os = "ios")), not(target_os = "linux")))]',
    )
    text = text.replace(
        '#[cfg(target_os = "android")]',
        '#[cfg(any(target_os = "android", target_os = "ios"))]',
    )
    text = text.replace('unavailable on Android', 'unavailable on this mobile platform')
    copy.write_text(text)

clipboard_text = Path('codex-rs/tui/src/clipboard_text.rs')
if clipboard_text.exists():
    text = clipboard_text.read_text()
    text = text.replace(
        '#[cfg(not(target_os = "android"))]',
        '#[cfg(not(any(target_os = "android", target_os = "ios")))]',
    )
    text = text.replace(
        '#[cfg(target_os = "android")]',
        '#[cfg(any(target_os = "android", target_os = "ios"))]',
    )
    text = text.replace('unsupported on Android', 'unsupported on this mobile platform')
    clipboard_text.write_text(text)

# set_core_file_size_limit_to_zero() is cfg(unix), but its error constant omitted
# iOS even though libc::setrlimit and RLIMIT_CORE are available there.
hardening = Path('codex-rs/process-hardening/src/lib.rs')
text = hardening.read_text()
old = '''    target_os = "macos",
    target_os = "freebsd",'''
new = '''    target_os = "macos",
    target_os = "ios",
    target_os = "freebsd",'''
if old not in text:
    raise SystemExit('process-hardening platform list changed upstream')
hardening.write_text(text.replace(old, new, 1))
PY

grep -q 'target_os = "ios"' codex-rs/tui/Cargo.toml
grep -q 'target_os = "ios"' codex-rs/tui/src/clipboard_paste.rs
grep -q 'target_os = "ios"' codex-rs/tui/src/clipboard_text.rs
grep -q 'target_os = "ios"' codex-rs/process-hardening/src/lib.rs

# OpenAI's rust-toolchain.toml lives inside codex-rs. Install the iOS standard
# library into that exact pinned toolchain rather than the runner default.
TOOLCHAIN="$(cd codex-rs && rustup show active-toolchain | awk '{print $1}')"
printf 'Codex Rust toolchain: %s\n' "$TOOLCHAIN"
rustup target add --toolchain "$TOOLCHAIN" aarch64-apple-ios
SYSROOT="$(cd codex-rs && rustc --print sysroot)"
test -d "$SYSROOT/lib/rustlib/aarch64-apple-ios/lib"
(cd codex-rs && rustup target list --installed | grep -qx aarch64-apple-ios)

# iOS has no Codex platform sandbox implementation. Upstream maps unsupported
# host platforms to no platform sandbox. The package exposes codex-root only for
# an explicit jailbreak-level run. OAuth endpoints and client IDs stay official.
unset MACOSX_DEPLOYMENT_TARGET || true

printf '%s\n' 'Upstream validation complete; using official pre-V8 Codex with iOS platform cfgs, device-code OAuth, and the iOS Rust target.'
