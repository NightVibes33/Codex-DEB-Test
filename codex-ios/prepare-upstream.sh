#!/usr/bin/env bash
set -euo pipefail

# This script runs from the root of the official openai/codex checkout.
# Keep source modifications minimal so the iOS port tracks upstream closely.

test -f codex-rs/Cargo.toml
test -f codex-rs/cli/src/main.rs
test -f codex-rs/login/src/device_code_auth.rs
test -f codex-rs/rust-toolchain.toml

grep -q 'device-auth' codex-rs/cli/src/main.rs

# OpenAI's rust-toolchain.toml lives inside codex-rs, so commands run from the
# repository root otherwise use the runner's default toolchain. Resolve the
# nested override and install the iOS standard library into that exact toolchain.
TOOLCHAIN="$(cd codex-rs && rustup show active-toolchain | awk '{print $1}')"
printf 'Codex Rust toolchain: %s\n' "$TOOLCHAIN"
rustup target add --toolchain "$TOOLCHAIN" aarch64-apple-ios
SYSROOT="$(cd codex-rs && rustc --print sysroot)"
test -d "$SYSROOT/lib/rustlib/aarch64-apple-ios/lib"
(cd codex-rs && rustup target list --installed | grep -qx aarch64-apple-ios)

# iOS has no Codex platform sandbox implementation. Upstream already maps
# non-macOS/Linux/Windows hosts to SandboxType::None. The jailbroken-device
# package exposes a separate codex-root wrapper for explicit unrestricted use.
# Do not rewrite ChatGPT OAuth endpoints or client IDs.

# Some build scripts inspect the host deployment variable even during a cross
# build. Clear it and use only IPHONEOS_DEPLOYMENT_TARGET in the workflow.
unset MACOSX_DEPLOYMENT_TARGET || true

printf '%s\n' 'Upstream validation complete; Codex pinned toolchain has the iOS target and official device-code OAuth is unchanged.'
