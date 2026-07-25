# AlleyCat emexDE failure probe

- Failed job: 89648238054
- Job-log API status: 0
- Release: NightVibes33/litter@emexde-corecompiler
- Release API status: 0

## Release assets
```text
CoreCompiler.framework.tar.xz	34811988 bytes	https://github.com/NightVibes33/litter/releases/download/emexde-corecompiler/CoreCompiler.framework.tar.xz
CoreCompilerSupportLibs.tar.xz	2626220 bytes	https://github.com/NightVibes33/litter/releases/download/emexde-corecompiler/CoreCompilerSupportLibs.tar.xz
LLVM.xcframework.tar.xz	39836168 bytes	https://github.com/NightVibes33/litter/releases/download/emexde-corecompiler/LLVM.xcframework.tar.xz
```

## Failed step errors
```text
32:2026-07-25T05:38:10.7819210Z Download action repository 'dtolnay/rust-toolchain@stable' (SHA:4cda84d5c5c54efe2404f9d843567869ab1699d4)
34:2026-07-25T05:38:18.3472040Z Download action repository 'actions/upload-artifact@v4' (SHA:ea165f8d65b6e75b540449e92b4886f43607fa02)
94:2026-07-25T05:38:19.7540460Z hint:
151:2026-07-25T05:38:28.4033580Z Updating files:  28% (4555/16266)
236:2026-07-25T05:38:33.4440470Z with:
400:2026-07-25T05:39:17.8240850Z Cache not found for input keys: homebrew-ios-macOS-xcodegen-native-tools-v5
424:2026-07-25T05:39:17.8740440Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
661:2026-07-25T05:39:49.9540460Z shell: /bin/bash --noprofile --norc -e -o pipefail {0}
730:2026-07-25T05:39:50.4524040Z   CARGO_INCREMENTAL: 0
977:2026-07-25T05:40:12.9193880Z Cache not found for input keys: ios-cargo-registry-macOS-e692f0ec6f47c79c4db217a3ee6814d0de586a9b0c9fae863006aa632720cf44, ios-cargo-registry-macOS-
1018:2026-07-25T05:40:13.7133570Z Cache not found for input keys: alleycat-zig-global-macOS-11411bc7bd232219d842d100dd6e83c227f47e0f18bca5c5ac68694a6980c49a, alleycat-zig-global-macOS-
1059:2026-07-25T05:40:14.2387180Z Cache not found for input keys: rusty-v8-149.2.0-macOS-x86_64-apple-darwin, rusty-v8-149.2.0-macOS-
1260:2026-07-25T05:41:14.2495380Z Cache not found for input keys: ios-alpine-fs-v1-macOS-470f63b1d69d52a48a62bdead0e7425c28c071f76b05833a873eb87167f432ac, ios-alpine-fs-v1-macOS-
1285:2026-07-25T05:41:14.2740310Z   IOS_MIN: 16.1
1317:2026-07-25T05:41:20.1094410Z ##[error]Process completed with exit code 2.

--- final 220 lines ---
2026-07-25T05:41:13.6509710Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T05:41:13.6510480Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T05:41:13.6511140Z   CARGO_INCREMENTAL: 0
2026-07-25T05:41:13.6512510Z   CARGO_BUILD_JOBS: 2
2026-07-25T05:41:13.6515000Z   CARGO_NET_RETRY: 10
2026-07-25T05:41:13.6518070Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T05:41:13.6520530Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T05:41:13.6521490Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T05:41:13.6523530Z   IOS_MIN: 16.1
2026-07-25T05:41:13.6527880Z   RUSTC_WRAPPER: 
2026-07-25T05:41:13.6530160Z   SCCACHE_DISABLE: 1
2026-07-25T05:41:13.6532150Z   SOURCE_ROOT: upstream/litter
2026-07-25T05:41:13.6535430Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T05:41:13.6539690Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T05:41:13.6542470Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T05:41:13.6545170Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T05:41:13.6546940Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T05:41:13.6547680Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T05:41:13.6548410Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T05:41:13.6549480Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T05:41:13.6550350Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T05:41:13.6551110Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T05:41:13.6551870Z   CARGO_TERM_COLOR: always
2026-07-25T05:41:13.6552830Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:13.6555330Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:13.6556810Z ##[endgroup]
2026-07-25T05:41:13.9635240Z (node:11832) [DEP0040] DeprecationWarning: The `punycode` module is deprecated. Please use a userland alternative instead.
2026-07-25T05:41:13.9638130Z (Use `node --trace-deprecation ...` to show where the warning was created)
2026-07-25T05:41:14.2495380Z Cache not found for input keys: ios-alpine-fs-v1-macOS-470f63b1d69d52a48a62bdead0e7425c28c071f76b05833a873eb87167f432ac, ios-alpine-fs-v1-macOS-
2026-07-25T05:41:14.2638120Z ##[group]Run set -euo pipefail
2026-07-25T05:41:14.2638860Z [36;1mset -euo pipefail[0m
2026-07-25T05:41:14.2639520Z [36;1mmkdir -p "$GITHUB_WORKSPACE/build/logs"[0m
2026-07-25T05:41:14.2640560Z [36;1mexport GHOSTTY_ZIG_GLOBAL_CACHE_DIR="$HOME/.cache/darksword-zig-global"[0m
2026-07-25T05:41:14.2641580Z [36;1mif [[ "true" == "true" ]]; then[0m
2026-07-25T05:41:14.2642910Z [36;1m  echo "Using cached AlleyCat GeneratedRust assets" | tee "$GITHUB_WORKSPACE/build/logs/runtime-build.log"[0m
2026-07-25T05:41:14.2644160Z [36;1melse[0m
2026-07-25T05:41:14.2644790Z [36;1m  ./apps/ios/scripts/sync-codex.sh --preserve-current[0m
2026-07-25T05:41:14.2646190Z [36;1m  export RUSTY_V8_ARCHIVE="/Users/runner/.cargo/.rusty_v8/librusty_v8_release_x86_64-apple-darwin.a.gz"[0m
2026-07-25T05:41:14.2647450Z [36;1m  test -s "$RUSTY_V8_ARCHIVE"[0m
2026-07-25T05:41:14.2648970Z [36;1m  ./apps/ios/scripts/build-rust.sh --preserve-current --device-only 2>&1 | tee "$GITHUB_WORKSPACE/build/logs/runtime-build.log"[0m
2026-07-25T05:41:14.2650400Z [36;1mfi[0m
2026-07-25T05:41:14.2651400Z [36;1mmake RUSTC_WRAPPER= SCCACHE_BUCKET= SCCACHE_ENDPOINT= AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= \[0m
2026-07-25T05:41:14.2652790Z [36;1m  alpine-fs xcgen IOS_DEPLOYMENT_TARGET="$IOS_MIN"[0m
2026-07-25T05:41:14.2734280Z shell: /bin/bash -e {0}
2026-07-25T05:41:14.2735180Z env:
2026-07-25T05:41:14.2735670Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T05:41:14.2736360Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T05:41:14.2736970Z   CARGO_INCREMENTAL: 0
2026-07-25T05:41:14.2737470Z   CARGO_BUILD_JOBS: 2
2026-07-25T05:41:14.2737960Z   CARGO_NET_RETRY: 10
2026-07-25T05:41:14.2738520Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T05:41:14.2739100Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T05:41:14.2739720Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T05:41:14.2740310Z   IOS_MIN: 16.1
2026-07-25T05:41:14.2740810Z   RUSTC_WRAPPER: 
2026-07-25T05:41:14.2741290Z   SCCACHE_DISABLE: 1
2026-07-25T05:41:14.2741810Z   SOURCE_ROOT: upstream/litter
2026-07-25T05:41:14.2742810Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T05:41:14.2743880Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T05:41:14.2744650Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T05:41:14.2745570Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T05:41:14.2746290Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T05:41:14.2746930Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T05:41:14.2747720Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T05:41:14.2748430Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T05:41:14.2749130Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T05:41:14.2749880Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T05:41:14.2750490Z   CARGO_TERM_COLOR: always
2026-07-25T05:41:14.2751410Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:14.2752750Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:14.2753780Z ##[endgroup]
2026-07-25T05:41:14.3133980Z Using cached AlleyCat GeneratedRust assets
2026-07-25T05:41:18.8004480Z ==> Fetching alpine-fs v0.1.2...
2026-07-25T05:41:18.8409890Z ==> Downloading fs.tar.gz
2026-07-25T05:41:19.4510840Z ==> Downloading SHA256SUMS
2026-07-25T05:41:19.8522330Z ==> Verifying checksum for fs.tar.gz
2026-07-25T05:41:19.9026620Z fs.tar.gz: OK
2026-07-25T05:41:19.9033650Z ==> Installing fs archive
2026-07-25T05:41:19.9220100Z 
2026-07-25T05:41:19.9223450Z alpine-fs v0.1.2 archive installed:
2026-07-25T05:41:19.9302470Z 3.7M	/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/Resources/fs.tar.gz
2026-07-25T05:41:19.9514710Z ==> Regenerating Xcode project...
2026-07-25T05:41:19.9817110Z ==> Restoring emexDE CoreCompiler/LLVM assets for full AlleyCat sideload build
2026-07-25T05:41:20.0942150Z tools/scripts/prepare-emexde-corecompiler-artifacts.sh: line 23: AUTH_HEADER[@]: unbound variable
2026-07-25T05:41:20.1051010Z make: *** [xcgen] Error 1
2026-07-25T05:41:20.1094410Z ##[error]Process completed with exit code 2.
2026-07-25T05:41:20.1199100Z ##[group]Run set -euo pipefail
2026-07-25T05:41:20.1199920Z [36;1mset -euo pipefail[0m
2026-07-25T05:41:20.1200520Z [36;1mmkdir -p build-diagnostics[0m
2026-07-25T05:41:20.1201170Z [36;1m{[0m
2026-07-25T05:41:20.1201700Z [36;1m  echo '# AlleyCat unsigned IPA failure'[0m
2026-07-25T05:41:20.1202420Z [36;1m  echo[0m
2026-07-25T05:41:20.1202950Z [36;1m  echo "- Run: $GITHUB_RUN_ID"[0m
2026-07-25T05:41:20.1203610Z [36;1m  echo "- Commit: $GITHUB_SHA"[0m
2026-07-25T05:41:20.1204320Z [36;1m  echo '- Workflow: ios-unsigned-ipa.yml'[0m
2026-07-25T05:41:20.1205080Z [36;1m  echo "- Rust cache hit: true"[0m
2026-07-25T05:41:20.1206100Z [36;1m  for log in runtime-build xcodebuild; do[0m
2026-07-25T05:41:20.1206820Z [36;1m    echo[0m
2026-07-25T05:41:20.1207300Z [36;1m    echo "## $log tail"[0m
2026-07-25T05:41:20.1207910Z [36;1m    echo '```text'[0m
2026-07-25T05:41:20.1208610Z [36;1m    tail -n 500 "build/logs/$log.log" 2>/dev/null || true[0m
2026-07-25T05:41:20.1209490Z [36;1m    echo '```'[0m
2026-07-25T05:41:20.1210040Z [36;1m  done[0m
2026-07-25T05:41:20.1210640Z [36;1m} > build-diagnostics/alleycat-ios-last-error.md[0m
2026-07-25T05:41:20.1211520Z [36;1mgit config user.name github-actions[bot][0m
2026-07-25T05:41:20.1213090Z [36;1mgit config user.email 41898282+github-actions[bot]@users.noreply.github.com[0m
2026-07-25T05:41:20.1214300Z [36;1mgit add build-diagnostics/alleycat-ios-last-error.md[0m
2026-07-25T05:41:20.1215340Z [36;1mgit commit -m 'Record AlleyCat IPA failure [skip ci]' || exit 0[0m
2026-07-25T05:41:20.1216300Z [36;1mgit pull --rebase origin main[0m
2026-07-25T05:41:20.1217210Z [36;1mgit push origin HEAD:main[0m
2026-07-25T05:41:20.1307090Z shell: /bin/bash -e {0}
2026-07-25T05:41:20.1307640Z env:
2026-07-25T05:41:20.1308120Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T05:41:20.1308830Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T05:41:20.1309400Z   CARGO_INCREMENTAL: 0
2026-07-25T05:41:20.1309890Z   CARGO_BUILD_JOBS: 2
2026-07-25T05:41:20.1310400Z   CARGO_NET_RETRY: 10
2026-07-25T05:41:20.1310930Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T05:41:20.1311500Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T05:41:20.1312140Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T05:41:20.1312760Z   IOS_MIN: 16.1
2026-07-25T05:41:20.1313240Z   RUSTC_WRAPPER: 
2026-07-25T05:41:20.1313740Z   SCCACHE_DISABLE: 1
2026-07-25T05:41:20.1314270Z   SOURCE_ROOT: upstream/litter
2026-07-25T05:41:20.1315280Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T05:41:20.1316340Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T05:41:20.1317130Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T05:41:20.1318040Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T05:41:20.1318690Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T05:41:20.1319320Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T05:41:20.1319990Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T05:41:20.1320700Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T05:41:20.1321380Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T05:41:20.1322130Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T05:41:20.1322790Z   CARGO_TERM_COLOR: always
2026-07-25T05:41:20.1323680Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:20.1325040Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:20.1326040Z ##[endgroup]
2026-07-25T05:41:21.1182510Z [main 1a6e864] Record AlleyCat IPA failure [skip ci]
2026-07-25T05:41:21.1183510Z  1 file changed, 8 insertions(+), 2 deletions(-)
2026-07-25T05:41:21.6751850Z From https://github.com/NightVibes33/Codex-DEB-Test
2026-07-25T05:41:21.6763140Z  * branch            main       -> FETCH_HEAD
2026-07-25T05:41:21.7326780Z Current branch main is up to date.
2026-07-25T05:41:22.8921760Z To https://github.com/NightVibes33/Codex-DEB-Test
2026-07-25T05:41:22.9035020Z    a6d6f2e..1a6e864  HEAD -> main
2026-07-25T05:41:22.9239770Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T05:41:22.9243660Z ##[group]Run actions/upload-artifact@v4
2026-07-25T05:41:22.9244360Z with:
2026-07-25T05:41:22.9244900Z   name: AlleyCat-IPA-Build-Logs-30146101117
2026-07-25T05:41:22.9245710Z   path: build/logs/
build-diagnostics/

2026-07-25T05:41:22.9246430Z   if-no-files-found: warn
2026-07-25T05:41:22.9247050Z   compression-level: 6
2026-07-25T05:41:22.9247680Z   overwrite: false
2026-07-25T05:41:22.9248220Z   include-hidden-files: false
2026-07-25T05:41:22.9248800Z env:
2026-07-25T05:41:22.9249310Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T05:41:22.9250090Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T05:41:22.9250660Z   CARGO_INCREMENTAL: 0
2026-07-25T05:41:22.9251320Z   CARGO_BUILD_JOBS: 2
2026-07-25T05:41:22.9251910Z   CARGO_NET_RETRY: 10
2026-07-25T05:41:22.9252460Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T05:41:22.9253080Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T05:41:22.9253770Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T05:41:22.9255010Z   IOS_MIN: 16.1
2026-07-25T05:41:22.9255500Z   RUSTC_WRAPPER: 
2026-07-25T05:41:22.9256020Z   SCCACHE_DISABLE: 1
2026-07-25T05:41:22.9256620Z   SOURCE_ROOT: upstream/litter
2026-07-25T05:41:22.9257660Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T05:41:22.9258830Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T05:41:22.9259700Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T05:41:22.9260690Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T05:41:22.9261390Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T05:41:22.9262120Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T05:41:22.9262900Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T05:41:22.9263630Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T05:41:22.9264370Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T05:41:22.9265210Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T05:41:22.9265880Z   CARGO_TERM_COLOR: always
2026-07-25T05:41:22.9266840Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:22.9268350Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T05:41:22.9269440Z ##[endgroup]
2026-07-25T05:41:23.3001970Z (node:12248) [DEP0040] DeprecationWarning: The `punycode` module is deprecated. Please use a userland alternative instead.
2026-07-25T05:41:23.3275970Z (Use `node --trace-deprecation ...` to show where the warning was created)
2026-07-25T05:41:23.7077630Z Multiple search paths detected. Calculating the least common ancestor of all paths
2026-07-25T05:41:23.7085100Z The least common ancestor is /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test. This will be the root directory of the artifact
2026-07-25T05:41:23.7087900Z With the provided path, there will be 4 files uploaded
2026-07-25T05:41:23.7091150Z Artifact name is valid!
2026-07-25T05:41:23.7092730Z Root directory input is valid!
2026-07-25T05:41:23.7161070Z (node:12248) [DEP0169] DeprecationWarning: `url.parse()` behavior is not standardized and prone to errors that have security implications. Use the WHATWG URL API instead. CVEs are not issued for `url.parse()` vulnerabilities.
2026-07-25T05:41:23.7164720Z Beginning upload of artifact content to blob storage
2026-07-25T05:41:24.0543060Z Uploaded bytes 2796
2026-07-25T05:41:24.2026170Z Finished uploading artifact content to blob storage!
2026-07-25T05:41:24.2030130Z SHA256 digest of uploaded artifact zip is f631905779ef6e312839ab42ed0afb11a30e0d15b9fbc1bc22ba2c99cd67bb61
2026-07-25T05:41:24.2032030Z Finalizing artifact upload
2026-07-25T05:41:24.4245860Z Artifact AlleyCat-IPA-Build-Logs-30146101117.zip successfully finalized. Artifact ID 8616078445
2026-07-25T05:41:24.4313480Z Artifact AlleyCat-IPA-Build-Logs-30146101117 has been successfully uploaded! Final size is 2796 bytes. Artifact ID is 8616078445
2026-07-25T05:41:24.4744560Z Artifact download URL: https://github.com/NightVibes33/Codex-DEB-Test/actions/runs/30146101117/artifacts/8616078445
2026-07-25T05:41:24.5149820Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T05:41:24.5153500Z Post job cleanup.
2026-07-25T05:41:25.3177900Z Zig cache directory is inaccessible; nothing to save
2026-07-25T05:41:25.3694470Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T05:41:25.3701670Z Post job cleanup.
2026-07-25T05:41:25.6322090Z [command]/usr/local/bin/git version
2026-07-25T05:41:25.6485980Z git version 2.55.0
2026-07-25T05:41:25.6557820Z Copying '/Users/runner/.gitconfig' to '/Users/runner/work/_temp/de31ec7e-1b7a-4889-995b-52ebf9a30114/.gitconfig'
2026-07-25T05:41:25.6595500Z Temporarily overriding HOME='/Users/runner/work/_temp/de31ec7e-1b7a-4889-995b-52ebf9a30114' before making global git config changes
2026-07-25T05:41:25.6602630Z Adding repository directory to the temporary git global config as a safe directory
2026-07-25T05:41:25.6607260Z [command]/usr/local/bin/git config --global --add safe.directory /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test
2026-07-25T05:41:25.6849330Z [command]/usr/local/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-07-25T05:41:25.7207550Z [command]/usr/local/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-07-25T05:41:25.9249940Z [command]/usr/local/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-07-25T05:41:25.9363270Z http.https://github.com/.extraheader
2026-07-25T05:41:25.9405640Z [command]/usr/local/bin/git config --local --unset-all http.https://github.com/.extraheader
2026-07-25T05:41:25.9521660Z [command]/usr/local/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-07-25T05:41:26.1835210Z [command]/usr/local/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-07-25T05:41:26.1871940Z [command]/usr/local/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-07-25T05:41:26.3879080Z Cleaning up orphan processes
2026-07-25T05:41:26.9583360Z ##[warning]Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on Node.js 24: actions/cache/restore@v4, actions/cache@v4, actions/checkout@v4, actions/upload-artifact@v4, mlugg/setup-zig@v2. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
```
