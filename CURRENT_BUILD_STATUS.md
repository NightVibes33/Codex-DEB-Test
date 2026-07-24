# Current IPA and DEB build status

- Run: 30103673729
- Commit: ae0fb77181882eeffcb289f312a2988ae93749f2
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Runtime/Xcode project: failure
- iOS application: skipped
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## runtime-build tail
```text
  CFLAGS_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_FORCE_DISABLE
  CC_FORCE_DISABLE = None
  cargo:rerun-if-env-changed=CC_aarch64-apple-darwin
  CC_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_aarch64_apple_darwin
  CC_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CC
  HOST_CC = None
  cargo:rerun-if-env-changed=CC
  CC = None
  cargo:rerun-if-env-changed=CRATE_CC_NO_DEFAULTS
  CRATE_CC_NO_DEFAULTS = None
  cargo:rerun-if-env-changed=CFLAGS
  CFLAGS = None
  cargo:rerun-if-env-changed=HOST_CFLAGS
  HOST_CFLAGS = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64_apple_darwin
  CFLAGS_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64-apple-darwin
  CFLAGS_aarch64-apple-darwin = None
  cargo:warning=Compilation of 'builtin_swap_check.c' succeeded - Ok(["/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/target/debug/build/aws-lc-sys-b446d4cc02b9accc/out/out-builtin_swap_check/7dfda64fdf5a526c-builtin_swap_check.o"]).
  cargo:rerun-if-env-changed=CC_aarch64-apple-darwin
  CC_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_aarch64_apple_darwin
  CC_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CC
  HOST_CC = None
  cargo:rerun-if-env-changed=CC
  CC = None
  cargo:rerun-if-env-changed=CC_ENABLE_DEBUG_OUTPUT
  cargo:rerun-if-env-changed=CRATE_CC_NO_DEFAULTS
  CRATE_CC_NO_DEFAULTS = None
  cargo:rerun-if-env-changed=MACOSX_DEPLOYMENT_TARGET
  MACOSX_DEPLOYMENT_TARGET = Some(14.0)
  cargo:rerun-if-env-changed=CFLAGS
  CFLAGS = None
  cargo:rerun-if-env-changed=HOST_CFLAGS
  HOST_CFLAGS = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64_apple_darwin
  CFLAGS_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64-apple-darwin
  CFLAGS_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_FORCE_DISABLE
  CC_FORCE_DISABLE = None
  cargo:rerun-if-env-changed=CC_aarch64-apple-darwin
  CC_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_aarch64_apple_darwin
  CC_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CC
  HOST_CC = None
  cargo:rerun-if-env-changed=CC
  CC = None
  cargo:rerun-if-env-changed=CRATE_CC_NO_DEFAULTS
  CRATE_CC_NO_DEFAULTS = None
  cargo:rerun-if-env-changed=CFLAGS
  CFLAGS = None
  cargo:rerun-if-env-changed=HOST_CFLAGS
  HOST_CFLAGS = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64_apple_darwin
  CFLAGS_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64-apple-darwin
  CFLAGS_aarch64-apple-darwin = None
  cargo:warning=Compilation of 'neon_sha3_check.c' succeeded - Ok(["/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/target/debug/build/aws-lc-sys-b446d4cc02b9accc/out/out-neon_sha3_check/7dfda64fdf5a526c-neon_sha3_check.o"]).
  cargo:rerun-if-env-changed=CC_aarch64-apple-darwin
  CC_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_aarch64_apple_darwin
  CC_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CC
  HOST_CC = None
  cargo:rerun-if-env-changed=CC
  CC = None
  cargo:rerun-if-env-changed=CC_ENABLE_DEBUG_OUTPUT
  cargo:rerun-if-env-changed=CRATE_CC_NO_DEFAULTS
  CRATE_CC_NO_DEFAULTS = None
  cargo:rerun-if-env-changed=MACOSX_DEPLOYMENT_TARGET
  MACOSX_DEPLOYMENT_TARGET = Some(14.0)
  cargo:rerun-if-env-changed=CFLAGS
  CFLAGS = None
  cargo:rerun-if-env-changed=HOST_CFLAGS
  HOST_CFLAGS = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64_apple_darwin
  CFLAGS_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64-apple-darwin
  CFLAGS_aarch64-apple-darwin = None

  --- stderr

  thread 'main' (65122) panicked at /Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/aws-lc-sys-0.42.0/builder/cc_builder.rs:872:9:
  ### COMPILER BUG DETECTED ###
  Your compiler (cc) is not supported due to a memcmp related bug reported in https://gcc.gnu.org/bugzilla/show_bug.cgi?id=95189. We strongly recommend against using this compiler. 
  EXECUTED: true
  ERROR: clang: warning: using sysroot for 'MacOSX' but targeting 'iPhone' [-Wincompatible-sysroot]
  ld: warning: <rdar://113405968> building for 'iOS', but linking in dylib (/Applications/Xcode_16.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib/libSystem.B.tbd) built for 'macOS macCatalyst zippered(macOS/Catalyst)'

  OUTPUT: 

  note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
warning: build failed, waiting for other jobs to finish...
make: *** [rust-ios-device-fast] Error 101
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
