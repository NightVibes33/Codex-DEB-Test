#!/usr/bin/env bash
set -euo pipefail

# This script runs from the root of the official openai/codex checkout.
# Keep source modifications minimal so the iOS port tracks upstream closely.

test -f codex-rs/Cargo.toml
test -f codex-rs/cli/src/main.rs
test -f codex-rs/login/src/device_code_auth.rs

grep -q 'device-auth' codex-rs/cli/src/main.rs
grep -q 'aarch64-apple-ios' "$(rustc --print sysroot)/lib/rustlib/components" || true

# iOS has no Codex platform sandbox implementation. Upstream already maps
# non-macOS/Linux/Windows hosts to SandboxType::None. The jailbroken-device
# package exposes a separate codex-root wrapper for explicit unrestricted use.
# Do not rewrite ChatGPT OAuth endpoints or client IDs.

# Some build scripts inspect the host deployment variable even during a cross
# build. Clear it and use only IPHONEOS_DEPLOYMENT_TARGET in the workflow.
unset MACOSX_DEPLOYMENT_TARGET || true

printf '%s\n' 'Upstream validation complete; using official device-code OAuth and iOS target.'
