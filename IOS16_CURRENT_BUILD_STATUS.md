# Current DarkSword iOS 16 build status

- Run ID: 30093132862
- Source commit: 725572ebc2afb72baddec737ad54a4c9ea35c32b
- Toolchain: success
- Dependencies: success
- Codex/Ghostty restore: success
- DarkSword overlay: success
- Full-source verification: success
- Rust/Codex/Ghostty build: failure
- iOS app and embedded targets: skipped
- Root daemon: success
- IPA/DEB package: skipped

## toolchain errors
```text
```

## toolchain log tail
```text
source_sha=725572ebc2afb72baddec737ad54a4c9ea35c32b
Xcode 16.4
Build version 16F6
18.5
swift-driver version: 1.120.5 Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
Target: arm64-apple-macosx15.0
Apple clang version 17.0.0 (clang-1700.0.13.5)
Target: arm64-apple-darwin24.6.0
Thread model: posix
InstalledDir: /Applications/Xcode_16.4.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
```

## dependencies errors
```text
::error::Failure while executing; `/usr/bin/env GIT_TERMINAL_PROMPT=0 git clone https://github.com/ProcursusTeam/homebrew-Procursus /opt/homebrew/Library/Taps/procursusteam/homebrew-procursus --origin=origin --template= --config core.fsmonitor=false` exited with 128. Here's the output:%0ACloning into '/opt/homebrew/Library/Taps/procursusteam/homebrew-procursus'...%0Afatal: could not read Username for 'https://github.com': terminal prompts disabled%0A%0A
```

## dependencies log tail
```text
[32m==>[0m [1mInstalling dpkg dependency: [32mlibmd[39m[0m
[34m==>[0m [1mPouring libmd--1.2.0.arm64_sequoia.bottle.tar.gz[0m
🍺  /opt/homebrew/Cellar/libmd/1.2.0: 138 files, 1MB
[32m==>[0m [1mInstalling [32mdpkg[39m[0m
[34m==>[0m [1mPouring dpkg--1.23.7.arm64_sequoia.bottle.tar.gz[0m
[34m==>[0m [1mCaveats[0m
This installation of dpkg is not configured to install software, so
commands such as `dpkg -i`, `dpkg --configure` will fail.
[34m==>[0m [1mSummary[0m
🍺  /opt/homebrew/Cellar/dpkg/1.23.7: 740 files, 18.3MB
[32m==>[0m [1mInstalling llvm dependency: [32mz3[39m[0m
[34m==>[0m [1mPouring z3--4.16.0.arm64_sequoia.bottle.tar.gz[0m
🍺  /opt/homebrew/Cellar/z3/4.16.0: 128 files, 33.7MB
[32m==>[0m [1mInstalling [32mllvm[39m[0m
[34m==>[0m [1mPouring llvm--22.1.8.arm64_sequoia.bottle.tar.gz[0m
[34m==>[0m [1mCaveats[0m
CLANG_CONFIG_FILE_SYSTEM_DIR: /opt/homebrew/etc/clang
CLANG_CONFIG_FILE_USER_DIR:   ~/.config/clang

LLD is now provided in a separate formula:
  brew install lld

Using `clang`, `clang++`, etc., requires a CLT installation at `/Library/Developer/CommandLineTools`.
If you don't want to install the CLT, you can write appropriate configuration files pointing to your
SDK at ~/.config/clang.

To use the bundled libunwind please use the following LDFLAGS:
  LDFLAGS="-L/opt/homebrew/opt/llvm/lib/unwind -lunwind"

To use the bundled libc++ please use the following LDFLAGS:
  LDFLAGS="-L/opt/homebrew/opt/llvm/lib/c++ -L/opt/homebrew/opt/llvm/lib/unwind -lunwind"
Features newer than system libc++ will require the following define to enable
(support for this may be removed in a future major LLVM release):
  CPPFLAGS="-D_LIBCPP_DISABLE_AVAILABILITY"

NOTE: You probably want to use the libunwind and libc++ provided by macOS unless you know what you're doing.

llvm is keg-only, which means it was not symlinked into /opt/homebrew,
because macOS already provides this software and installing another version in
parallel can cause all kinds of trouble.

If you need to have llvm first in your PATH, run:
  echo 'export PATH="/opt/homebrew/opt/llvm/bin:$PATH"' >> /Users/runner/.bash_profile

For compilers to find llvm you may need to set:
  export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

For cmake to find llvm you may need to set:
  export CMAKE_PREFIX_PATH="/opt/homebrew/opt/llvm"
[34m==>[0m [1mSummary[0m
🍺  /opt/homebrew/Cellar/llvm/22.1.8: 9,693 files, 1.9GB
[32m==>[0m [1mInstalling autoconf dependency: [32mm4[39m[0m
[34m==>[0m [1mPouring m4--1.4.21.arm64_sequoia.bottle.tar.gz[0m
🍺  /opt/homebrew/Cellar/m4/1.4.21: 14 files, 816.2KB
[32m==>[0m [1mInstalling [32mautoconf[39m[0m
[34m==>[0m [1mPouring autoconf--2.73.arm64_sequoia.bottle.tar.gz[0m
🍺  /opt/homebrew/Cellar/autoconf/2.73: 73 files, 3.8MB
[34m==>[0m [1mPouring automake--1.18.1_1.arm64_sequoia.bottle.tar.gz[0m
🍺  /opt/homebrew/Cellar/automake/1.18.1_1: 134 files, 3.6MB
[34m==>[0m [1mPouring libtool--2.5.4.arm64_sequoia.bottle.tar.gz[0m
[34m==>[0m [1mCaveats[0m
All commands have been installed with the prefix "g".
If you need to use these commands with their normal names, you
can add a "gnubin" directory to your PATH from your bashrc like:
  PATH="/opt/homebrew/opt/libtool/libexec/gnubin:$PATH"
[34m==>[0m [1mSummary[0m
🍺  /opt/homebrew/Cellar/libtool/2.5.4: 76 files, 4.1MB
[32m==>[0m [1mCaveats[0m
Bash completion has been installed to:
  /opt/homebrew/etc/bash_completion.d
[34m==>[0m [1mdpkg[0m
This installation of dpkg is not configured to install software, so
commands such as `dpkg -i`, `dpkg --configure` will fail.
[34m==>[0m [1mllvm[0m
CLANG_CONFIG_FILE_SYSTEM_DIR: /opt/homebrew/etc/clang
CLANG_CONFIG_FILE_USER_DIR:   ~/.config/clang

LLD is now provided in a separate formula:
  brew install lld

Using `clang`, `clang++`, etc., requires a CLT installation at `/Library/Developer/CommandLineTools`.
If you don't want to install the CLT, you can write appropriate configuration files pointing to your
SDK at ~/.config/clang.

To use the bundled libunwind please use the following LDFLAGS:
  LDFLAGS="-L/opt/homebrew/opt/llvm/lib/unwind -lunwind"

To use the bundled libc++ please use the following LDFLAGS:
  LDFLAGS="-L/opt/homebrew/opt/llvm/lib/c++ -L/opt/homebrew/opt/llvm/lib/unwind -lunwind"
Features newer than system libc++ will require the following define to enable
(support for this may be removed in a future major LLVM release):
  CPPFLAGS="-D_LIBCPP_DISABLE_AVAILABILITY"

NOTE: You probably want to use the libunwind and libc++ provided by macOS unless you know what you're doing.

llvm is keg-only, which means it was not symlinked into /opt/homebrew,
because macOS already provides this software and installing another version in
parallel can cause all kinds of trouble.

If you need to have llvm first in your PATH, run:
  echo 'export PATH="/opt/homebrew/opt/llvm/bin:$PATH"' >> /Users/runner/.bash_profile

For compilers to find llvm you may need to set:
  export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

For cmake to find llvm you may need to set:
  export CMAKE_PREFIX_PATH="/opt/homebrew/opt/llvm"
[34m==>[0m [1mlibtool[0m
All commands have been installed with the prefix "g".
If you need to use these commands with their normal names, you
can add a "gnubin" directory to your PATH from your bashrc like:
  PATH="/opt/homebrew/opt/libtool/libexec/gnubin:$PATH"
[34m==>[0m [1mTapping procursusteam/procursus[0m
Cloning into '/opt/homebrew/Library/Taps/procursusteam/homebrew-procursus'...
fatal: could not read Username for 'https://github.com': terminal prompts disabled
::error::Failure while executing; `/usr/bin/env GIT_TERMINAL_PROMPT=0 git clone https://github.com/ProcursusTeam/homebrew-Procursus /opt/homebrew/Library/Taps/procursusteam/homebrew-procursus --origin=origin --template= --config core.fsmonitor=false` exited with 128. Here's the output:%0ACloning into '/opt/homebrew/Library/Taps/procursusteam/homebrew-procursus'...%0Afatal: could not read Username for 'https://github.com': terminal prompts disabled%0A%0A
::warning::The following taps are not trusted:%0A  aws/tap%0A%0AHomebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.%0AUntap them with:%0A  brew untap aws/tap%0ATrust specific formulae, casks and commands with:%0A  brew trust --formula <user>/<tap>/<formula>%0A  brew trust --cask <user>/<tap>/<cask>%0A  brew trust --command <user>/<tap>/<command>%0AWhole-tap trust is broader and includes all current and future formulae,%0Acasks and commands from the listed taps. Trust whole taps with:%0A  brew trust aws/tap%0ATo disable trust checks:%0A  export HOMEBREW_NO_REQUIRE_TAP_TRUST=1%0AThis is not recommended and will be removed in a later release.%0AFor more information, see:%0A  https://docs.brew.sh/Tap-Trust%0A
[34m==>[0m [1mWould install 1 formula:[0m
ldid
[34m==>[0m [1mDownloading https://ghcr.io/v2/homebrew/core/ldid/manifests/2.1.5_1-1[0m
[34m==>[0m [1mWould install 1 dependency for ldid:[0m
libplist
[32m==>[0m [1mFetching downloads for: [32mldid[39m[0m
✔︎ Bottle Manifest libplist (2.7.0)
✔︎ Bottle ldid (2.1.5_1)
✔︎ Bottle libplist (2.7.0)
[32m==>[0m [1mInstalling ldid dependency: [32mlibplist[39m[0m
[34m==>[0m [1mPouring libplist--2.7.0.arm64_sequoia.bottle.tar.gz[0m
🍺  /opt/homebrew/Cellar/libplist/2.7.0: 32 files, 604.1KB
[32m==>[0m [1mInstalling [32mldid[39m[0m
[34m==>[0m [1mPouring ldid--2.1.5_1.arm64_sequoia.bottle.1.tar.gz[0m
🍺  /opt/homebrew/Cellar/ldid/2.1.5_1: 6 files, 270KB
info: downloading component rust-std
info: downloading component rust-std
/opt/homebrew/bin/xcodegen
/opt/homebrew/bin/dpkg-deb
cargo 1.97.0 (c980f4866 2026-06-30)
rustc 1.97.0 (2d8144b78 2026-07-07)
```

## restore errors
```text
```

## restore log tail
```text
hint: Using 'master' as the name for the initial branch. This default branch name
hint: will change to "main" in Git 3.0. To configure the initial branch name
hint: to use in all of your new repositories, which will suppress this warning,
hint: call:
hint:
hint: 	git config --global init.defaultBranch <name>
hint:
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:
hint: 	git branch -m <name>
hint:
hint: Disable this message with "git config set advice.defaultBranchName false"
Initialized empty Git repository in /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/codex/.git/
From https://github.com/NightVibes33/codex
 * branch            b39d8b474aa039790503b9b4e34ca18696d9dfa6 -> FETCH_HEAD
HEAD is now at b39d8b4 Fix mobile code mode shell execution
hint: Using 'master' as the name for the initial branch. This default branch name
hint: will change to "main" in Git 3.0. To configure the initial branch name
hint: to use in all of your new repositories, which will suppress this warning,
hint: call:
hint:
hint: 	git config --global init.defaultBranch <name>
hint:
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:
hint: 	git branch -m <name>
hint:
hint: Disable this message with "git config set advice.defaultBranchName false"
Initialized empty Git repository in /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty/.git/
From https://github.com/ghostty-org/ghostty
 * branch            a968e120dd084bd886239d1cac938f0177f019d9 -> FETCH_HEAD
HEAD is now at a968e12 Update VOUCHED list (#12780)
```

## overlay errors
```text
```

## overlay log tail
```text
Exact DarkSword app architecture, full NightVibes Litter, iOS 16.1, pinned Zig, jailbreak lab, and rootless host runtime applied to /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter.
Perception iOS 16 backport applied: 6 Swift files changed, 13 View bodies wrapped, package revision de219a1cf34e958134e75a9ebb134cf09bf52fc6.
DarkSword core overlay and iOS 16 compatibility backports completed for upstream/litter.
```

## source-verify errors
```text
```

## source-verify log tail
```text
Nyxian source import verified: d955607acf4e8112c28d1db01837fc3e11631de3
KittyStore/Feather integration wiring verified.
```

## rust-and-project errors
```text
error: failed to run custom build command for `aws-lc-sys v0.42.0`
  Ignoring candidate AWS-LC at /opt/homebrew/Cellar/openssl@3/3.6.3: Failed to read /opt/homebrew/Cellar/openssl@3/3.6.3/include/openssl/base.h: No such file or directory (os error 2)
  Ignoring candidate AWS-LC at /opt/homebrew/Cellar/openssl@3/3.6.3: Failed to read /opt/homebrew/Cellar/openssl@3/3.6.3/include/openssl/base.h: No such file or directory (os error 2)
  ERROR: clang: warning: using sysroot for 'MacOSX' but targeting 'iPhone' [-Wincompatible-sysroot]
make: *** [rust-ios-device-fast] Error 101
```

## rust-and-project log tail
```text
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
  cargo:warning=Compilation of 'stdalign_check.c' succeeded - Ok(["/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/rust-bridge/target/debug/build/aws-lc-sys-b446d4cc02b9accc/out/out-stdalign_check/7dfda64fdf5a526c-stdalign_check.o"]).
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

  thread 'main' (89760) panicked at /Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/aws-lc-sys-0.42.0/builder/cc_builder.rs:872:9:
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

## xcodebuild errors
```text
```

## xcodebuild log tail
```text
```

## rootd-build errors
```text
```

## rootd-build log tail
```text
```
