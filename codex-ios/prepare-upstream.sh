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

printf '%s\n' 'Upstream validation complete; using official pre-V8 Codex with device-code OAuth and the iOS Rust target.'
