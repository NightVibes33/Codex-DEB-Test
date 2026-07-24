# Current DarkSword iOS 16 build status

- Run ID: 30094407102
- Source commit: b9eb0f2b718448cc0f2ab07a897d33fe83b8658a
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
source_sha=b9eb0f2b718448cc0f2ab07a897d33fe83b8658a
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
DarkSword core overlay, iOS Rust toolchain isolation, and iOS 16 compatibility backports completed for upstream/litter.
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
cp: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ios-device/libcodex_mobile_client.a: fcopyfile failed: No space left on device
make: *** [rust-ios-device-fast] Error 1
```

## rust-and-project log tail
```text
  --> codex-mobile-client/src/ish_runtime.rs:61:15
   |
61 | pub(crate) fn instance() -> Option<&'static IshInstance> {
   |               ^^^^^^^^

warning: function `instance_or_wait` is never used
  --> codex-mobile-client/src/ish_runtime.rs:70:21
   |
70 | pub(crate) async fn instance_or_wait(timeout: Duration) -> Option<&'static IshInstance> {
   |                     ^^^^^^^^^^^^^^^^

warning: function `synthesize_streaming_show_widget_arguments` is never used
    --> codex-mobile-client/src/conversation.rs:1379:15
     |
1379 | pub(crate) fn synthesize_streaming_show_widget_arguments(
     |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: constant `JSON_LOG_PREVIEW_LIMIT` is never used
 --> codex-mobile-client/src/logging/mod.rs:6:7
  |
6 | const JSON_LOG_PREVIEW_LIMIT: usize = 512;
  |       ^^^^^^^^^^^^^^^^^^^^^^

warning: function `summarize_json_for_log` is never used
   --> codex-mobile-client/src/logging/mod.rs:275:15
    |
275 | pub(crate) fn summarize_json_for_log(payload: &str) -> String {
    |               ^^^^^^^^^^^^^^^^^^^^^^

warning: function `truncate_log_preview` is never used
   --> codex-mobile-client/src/logging/mod.rs:284:4
    |
284 | fn truncate_log_preview(value: &str, limit: usize) -> String {
    |    ^^^^^^^^^^^^^^^^^^^^

warning: function `format_bytes` is never used
   --> codex-mobile-client/src/logging/mod.rs:298:4
    |
298 | fn format_bytes(bytes: usize) -> String {
    |    ^^^^^^^^^^^^

warning: function `deserialize_typed_response` is never used
   --> codex-mobile-client/src/mobile_client/event_loop.rs:440:4
    |
440 | fn deserialize_typed_response<R>(value: &serde_json::Value) -> Result<R, serde_json::Error>
    |    ^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `queued_follow_up_kind_from_json_value` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:118:15
    |
118 | pub(super) fn queued_follow_up_kind_from_json_value(
    |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `queued_follow_up_text_from_json_value` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:144:15
    |
144 | pub(super) fn queued_follow_up_text_from_json_value(value: &serde_json::Value) -> Option<String> {
    |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `queued_follow_up_inputs_from_json_value` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:172:15
    |
172 | pub(super) fn queued_follow_up_inputs_from_json_value(
    |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `string_field` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:343:15
    |
343 | pub(super) fn string_field(
    |               ^^^^^^^^^^^^

warning: function `array_field_len` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:368:15
    |
368 | pub(super) fn array_field_len(
    |               ^^^^^^^^^^^^^^^

warning: function `stable_follow_up_preview_id` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:386:15
    |
386 | pub(super) fn stable_follow_up_preview_id(scope: &str, index: usize, text: &str) -> String {
    |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `refresh_thread_list_from_app_server` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:567:21
    |
567 | pub(super) async fn refresh_thread_list_from_app_server(
    |                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `request_thread_list_page_for_runtime` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:637:10
    |
637 | async fn request_thread_list_page_for_runtime(
    |          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `normalize_empty_thread_list_cwds` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:655:4
    |
655 | fn normalize_empty_thread_list_cwds(value: &mut serde_json::Value) {
    |    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `thread_list_page_to_thread_infos` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:674:4
    |
674 | fn thread_list_page_to_thread_infos(
    |    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `upstream_thread_status_from_summary_status` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:755:15
    |
755 | pub(super) fn upstream_thread_status_from_summary_status(
    |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `thread_snapshot_from_upstream_thread` is never used
   --> codex-mobile-client/src/mobile_client/thread_projection.rs:767:15
    |
767 | pub(super) fn thread_snapshot_from_upstream_thread(
    |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: method `replace_pending_approvals_with_seeds` is never used
    --> codex-mobile-client/src/store/reducer.rs:1014:19
     |
 139 | impl AppStoreReducer {
     | -------------------- method in this implementation
...
1014 |     pub(crate) fn replace_pending_approvals_with_seeds(
     |                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: function `reconcile_local_overlay_items` is never used
    --> codex-mobile-client/src/store/reducer.rs:3348:15
     |
3348 | pub(crate) fn reconcile_local_overlay_items(thread: &mut ThreadSnapshot) {
     |               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

warning: `codex-mobile-client` (lib) generated 24 warnings
    Finished `ios-dev` profile [unoptimized + debuginfo] target(s) in 11m 42s
warning: the following packages contain code that will be rejected by a future version of Rust: proc-macro-error2 v2.0.1
note: to see what the problems were, use the option `--future-incompat-report`, or run `cargo report future-incompatibilities --id 1`
cp: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ios-device/libcodex_mobile_client.a: fcopyfile failed: No space left on device
make: *** [rust-ios-device-fast] Error 1
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
