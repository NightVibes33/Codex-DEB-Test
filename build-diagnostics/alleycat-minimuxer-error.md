# AlleyCat minimuxer failure

- Job: 89656272526

```text
89:2026-07-25T07:19:27.3898600Z hint: will change to "main" in Git 3.0. To configure the initial branch name
412:2026-07-25T07:20:59.7713600Z Cache not found for input keys: homebrew-ios-macOS-xcodegen-native-tools-v5
987:2026-07-25T07:22:02.6280050Z Cache not found for input keys: ios-cargo-registry-macOS-e692f0ec6f47c79c4db217a3ee6814d0de586a9b0c9fae863006aa632720cf44, ios-cargo-registry-macOS-
1028:2026-07-25T07:22:03.6655140Z Cache not found for input keys: alleycat-zig-global-macOS-11411bc7bd232219d842d100dd6e83c227f47e0f18bca5c5ac68694a6980c49a, alleycat-zig-global-macOS-
1069:2026-07-25T07:22:04.2822960Z Cache not found for input keys: rusty-v8-149.2.0-macOS-x86_64-apple-darwin, rusty-v8-149.2.0-macOS-
1270:2026-07-25T07:23:04.0110920Z Cache not found for input keys: ios-alpine-fs-v1-macOS-470f63b1d69d52a48a62bdead0e7425c28c071f76b05833a873eb87167f432ac, ios-alpine-fs-v1-macOS-
1324:2026-07-25T07:23:15.2037320Z ==> Building KittyStore minimuxer Rust bridge for full AlleyCat sideload build
1345:2026-07-25T07:23:34.8954940Z automake
1346:2026-07-25T07:23:34.9104090Z [34m==>[0m [1mDownloading https://ghcr.io/v2/homebrew/core/automake/manifests/1.18.1_1[0m
1347:2026-07-25T07:23:35.5350550Z [32m==>[0m [1mFetching downloads for: [32mautomake[39m[0m
1348:2026-07-25T07:23:36.1813900Z ✔︎ Bottle automake (1.18.1_1)
1349:2026-07-25T07:23:36.2111880Z [34m==>[0m [1mPouring automake--1.18.1_1.tahoe.bottle.tar.gz[0m
1350:2026-07-25T07:23:36.5343570Z 🍺  /usr/local/Cellar/automake/1.18.1_1: 134 files, 3.6MB
1417:2026-07-25T07:25:58.1413850Z For cmake to find llvm you may need to set:
1418:2026-07-25T07:25:58.1415650Z   export CMAKE_PREFIX_PATH="/usr/local/opt/llvm"
1455:2026-07-25T07:25:59.0932190Z For cmake to find llvm you may need to set:
1456:2026-07-25T07:25:59.0951410Z   export CMAKE_PREFIX_PATH="/usr/local/opt/llvm"
1457:2026-07-25T07:26:09.8433660Z ==> Using iOS deployment target 16.1 for KittyStore minimuxer Rust libraries
1458:2026-07-25T07:26:09.8449180Z ==> Installing bindgen-cli for aws-lc-sys
1461:2026-07-25T07:26:10.7699680Z [1m[92m  Downloaded[0m bindgen-cli v0.69.5
1462:2026-07-25T07:26:10.8813890Z [1m[92m  Installing[0m bindgen-cli v0.69.5
1505:2026-07-25T07:26:12.6915140Z [1m[92m  Downloaded[0m bindgen v0.69.5
1549:2026-07-25T07:27:19.7376320Z [1m[92m   Compiling[0m bindgen v0.69.5
1564:2026-07-25T07:30:29.4072360Z [1m[92m   Compiling[0m bindgen-cli v0.69.5
1566:2026-07-25T07:30:47.7579970Z [1m[92m  Installing[0m /Users/runner/.cargo/bin/bindgen
1567:2026-07-25T07:30:47.7591210Z [1m[92m   Installed[0m package `bindgen-cli v0.69.5` (executable `bindgen`)
1569:2026-07-25T07:30:48.1796470Z ==> Building KittyStore RustBridge for iOS device
1580:2026-07-25T07:30:53.2576910Z [1m[92m  Downloaded[0m aws-lc-rs v1.16.2
1587:2026-07-25T07:30:53.4695950Z [1m[92m  Downloaded[0m cmake v0.1.57
1659:2026-07-25T07:30:55.7251140Z [1m[92m  Downloaded[0m bindgen v0.59.2
1666:2026-07-25T07:30:55.8594640Z [1m[92m  Downloaded[0m aws-lc-sys v0.39.1
1852:2026-07-25T07:31:34.2975190Z [1m[92m   Compiling[0m cmake v0.1.57
1876:2026-07-25T07:32:11.8505530Z [1m[92m   Compiling[0m aws-lc-sys v0.39.1
1911:2026-07-25T07:33:09.5759590Z [1m[92m   Compiling[0m bindgen v0.59.2
1928:2026-07-25T07:33:51.2285090Z [1m[92m   Compiling[0m aws-lc-rs v1.16.2
2062:2026-07-25T07:40:03.1354130Z [1m[92m   Compiling[0m rust_bridge v1.0.0 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/Source/Dependencies/minimuxer/RustBridge)
2064:2026-07-25T07:41:29.5417750Z ==> Building KittyStore minimuxer for iOS device
2072:2026-07-25T07:41:32.5167340Z [1m[92m  Downloaded[0m aws-lc-rs v1.13.0
2080:2026-07-25T07:41:32.7950010Z [1m[92m  Downloaded[0m openssl v0.10.72
2115:2026-07-25T07:41:33.8446110Z [1m[92m  Downloaded[0m openssl-src v300.6.0+3.6.2
2192:2026-07-25T07:41:40.4183570Z [1m[92m  Downloaded[0m openssl-sys v0.9.107
2236:2026-07-25T07:41:42.2352520Z [1m[92m  Downloaded[0m cmake v0.1.54
2247:2026-07-25T07:41:42.8027090Z [1m[92m  Downloaded[0m openssl-macros v0.1.1
2252:2026-07-25T07:41:42.8719390Z [1m[92m  Downloaded[0m aws-lc-sys v0.28.0
2273:2026-07-25T07:42:00.9821400Z [1m[92m   Compiling[0m cmake v0.1.54
2303:2026-07-25T07:42:25.3134140Z [1m[92m   Compiling[0m aws-lc-sys v0.28.0
2336:2026-07-25T07:44:01.0278970Z [1m[92m   Compiling[0m aws-lc-rs v1.13.0
2357:2026-07-25T07:44:24.4523470Z [1m[92m   Compiling[0m bindgen v0.59.2
2395:2026-07-25T07:45:10.6195330Z [1m[92m   Compiling[0m openssl-src v300.6.0+3.6.2
2407:2026-07-25T07:45:15.3845570Z [1m[92m   Compiling[0m openssl-sys v0.9.107
2452:2026-07-25T07:48:09.0852140Z [1m[92m   Compiling[0m openssl v0.10.72
2472:2026-07-25T07:49:42.1347960Z [1m[92m   Compiling[0m openssl-macros v0.1.1
2487:2026-07-25T07:53:11.1662220Z [1m[91merror[0m: failed to run custom build command for `rusty_libimobiledevice v0.1.7 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/rusty_libimobiledevice)`
2490:2026-07-25T07:53:11.1806920Z   process didn't exit successfully: `/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/release/build/rusty_libimobiledevice-3bc978768e46d37f/build-script-build` (exit status: 101)
2494:2026-07-25T07:53:11.1937170Z   cargo:rustc-link-search=native=/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/openssl-sys-3f7abc064d2337f5/out/openssl-build/install/lib
2499:2026-07-25T07:53:11.2079620Z   called `Result::unwrap()` on an `Err` value: Os { code: 2, kind: NotFound, message: "No such file or directory" }
2501:2026-07-25T07:53:11.2087780Z [1m[33mwarning[0m: build failed, waiting for other jobs to finish...
2503:2026-07-25T07:53:18.3466090Z ##[error]Process completed with exit code 2.

--- final 400 lines ---
2026-07-25T07:41:42.2772040Z [1m[92m  Downloaded[0m tinyvec v1.9.0
2026-07-25T07:41:42.2970900Z [1m[92m  Downloaded[0m futures-task v0.3.31
2026-07-25T07:41:42.3057720Z [1m[92m  Downloaded[0m zerocopy v0.8.24
2026-07-25T07:41:42.6460680Z [1m[92m  Downloaded[0m libloading v0.8.6
2026-07-25T07:41:42.6600160Z [1m[92m  Downloaded[0m quick-xml v0.32.0
2026-07-25T07:41:42.6989860Z [1m[92m  Downloaded[0m fern v0.7.1
2026-07-25T07:41:42.7382410Z [1m[92m  Downloaded[0m icu_collections v1.5.0
2026-07-25T07:41:42.8027090Z [1m[92m  Downloaded[0m openssl-macros v0.1.1
2026-07-25T07:41:42.8081480Z [1m[92m  Downloaded[0m tempfile v3.19.1
2026-07-25T07:41:42.8340920Z [1m[92m  Downloaded[0m futures-channel v0.3.31
2026-07-25T07:41:42.8532350Z [1m[92m  Downloaded[0m deflate64 v0.1.9
2026-07-25T07:41:42.8626390Z [1m[92m  Downloaded[0m foreign-types-shared v0.1.1
2026-07-25T07:41:42.8719390Z [1m[92m  Downloaded[0m aws-lc-sys v0.28.0
2026-07-25T07:41:44.3280120Z [1m[92m  Downloaded[0m security-framework v2.11.1
2026-07-25T07:41:44.3595820Z [1m[92m  Downloaded[0m unicode-ident v1.0.18
2026-07-25T07:41:44.3828000Z [1m[92m  Downloaded[0m lockfree-object-pool v0.1.6
2026-07-25T07:41:44.4040570Z [1m[92m  Downloaded[0m icu_provider_macros v1.5.0
2026-07-25T07:41:44.7995450Z [1m[92m   Compiling[0m proc-macro2 v1.0.94
2026-07-25T07:41:44.8465580Z [1m[92m   Compiling[0m unicode-ident v1.0.18
2026-07-25T07:41:45.0023830Z [1m[92m   Compiling[0m libc v0.2.171
2026-07-25T07:41:47.3941060Z [1m[92m   Compiling[0m quote v1.0.40
2026-07-25T07:41:47.9321610Z [1m[92m   Compiling[0m syn v2.0.100
2026-07-25T07:41:48.3175910Z [1m[92m   Compiling[0m shlex v1.3.0
2026-07-25T07:41:48.6584620Z [1m[92m   Compiling[0m jobserver v0.1.33
2026-07-25T07:41:49.6522760Z [1m[92m   Compiling[0m cc v1.2.19
2026-07-25T07:41:55.6317180Z [1m[92m   Compiling[0m cfg-if v1.0.0
2026-07-25T07:41:55.7039200Z [1m[92m   Compiling[0m memchr v2.7.4
2026-07-25T07:41:57.3121750Z [1m[92m   Compiling[0m pkg-config v0.3.32
2026-07-25T07:41:58.2680430Z [1m[92m   Compiling[0m autocfg v1.4.0
2026-07-25T07:41:58.8810710Z [1m[92m   Compiling[0m itoa v1.0.15
2026-07-25T07:41:59.0602840Z [1m[92m   Compiling[0m serde v1.0.219
2026-07-25T07:41:59.5461200Z [1m[92m   Compiling[0m synstructure v0.13.1
2026-07-25T07:42:00.8819430Z [1m[92m   Compiling[0m pin-project-lite v0.2.16
2026-07-25T07:42:00.9821400Z [1m[92m   Compiling[0m cmake v0.1.54
2026-07-25T07:42:01.3318970Z [1m[92m   Compiling[0m serde_derive v1.0.219
2026-07-25T07:42:01.5841920Z [1m[92m   Compiling[0m zerofrom-derive v0.1.6
2026-07-25T07:42:04.4481250Z [1m[92m   Compiling[0m version_check v0.9.5
2026-07-25T07:42:05.0810650Z [1m[92m   Compiling[0m bytes v1.10.1
2026-07-25T07:42:07.7294980Z [1m[92m   Compiling[0m once_cell v1.21.3
2026-07-25T07:42:08.2099790Z [1m[92m   Compiling[0m typenum v1.18.0
2026-07-25T07:42:08.8489630Z [1m[92m   Compiling[0m futures-core v0.3.31
2026-07-25T07:42:09.1123510Z [1m[92m   Compiling[0m generic-array v0.14.7
2026-07-25T07:42:09.4705190Z [1m[92m   Compiling[0m zerofrom v0.1.6
2026-07-25T07:42:09.6977060Z [1m[92m   Compiling[0m yoke-derive v0.7.5
2026-07-25T07:42:11.7722270Z [1m[92m   Compiling[0m errno v0.3.11
2026-07-25T07:42:11.9651470Z [1m[92m   Compiling[0m stable_deref_trait v1.2.0
2026-07-25T07:42:12.1470710Z [1m[92m   Compiling[0m bitflags v2.9.0
2026-07-25T07:42:12.5056810Z [1m[92m   Compiling[0m yoke v0.7.5
2026-07-25T07:42:14.1479320Z [1m[92m   Compiling[0m zerovec-derive v0.10.3
2026-07-25T07:42:15.7693710Z [1m[92m   Compiling[0m slab v0.4.9
2026-07-25T07:42:16.2741250Z [1m[92m   Compiling[0m equivalent v1.0.2
2026-07-25T07:42:16.3794650Z [1m[92m   Compiling[0m hashbrown v0.15.2
2026-07-25T07:42:17.6384120Z [1m[92m   Compiling[0m futures-sink v0.3.31
2026-07-25T07:42:17.7923200Z [1m[92m   Compiling[0m zerovec v0.10.4
2026-07-25T07:42:18.0907620Z [1m[92m   Compiling[0m indexmap v2.9.0
2026-07-25T07:42:21.3855040Z [1m[92m   Compiling[0m displaydoc v0.2.5
2026-07-25T07:42:22.0870960Z [1m[92m   Compiling[0m tokio-macros v2.5.0
2026-07-25T07:42:22.5665730Z [1m[92m   Compiling[0m getrandom v0.2.15
2026-07-25T07:42:22.8655080Z [1m[92m   Compiling[0m mio v1.0.3
2026-07-25T07:42:23.2753560Z [1m[92m   Compiling[0m socket2 v0.5.9
2026-07-25T07:42:24.7636320Z [1m[92m   Compiling[0m fs_extra v1.3.0
2026-07-25T07:42:25.2123210Z [1m[92m   Compiling[0m dunce v1.0.5
2026-07-25T07:42:25.2495050Z [1m[92m   Compiling[0m log v0.4.27
2026-07-25T07:42:25.3134140Z [1m[92m   Compiling[0m aws-lc-sys v0.28.0
2026-07-25T07:42:25.7546470Z [1m[92m   Compiling[0m tokio v1.44.2
2026-07-25T07:42:27.1131520Z [1m[92m   Compiling[0m subtle v2.6.1
2026-07-25T07:42:27.4114830Z [1m[92m   Compiling[0m glob v0.3.2
2026-07-25T07:42:28.0698980Z [1m[92m   Compiling[0m clang-sys v1.8.1
2026-07-25T07:43:09.1910000Z [1m[92m   Compiling[0m tinystr v0.7.6
2026-07-25T07:43:09.8515280Z [1m[92m   Compiling[0m futures-channel v0.3.31
2026-07-25T07:43:10.3278790Z [1m[92m   Compiling[0m aho-corasick v1.1.3
2026-07-25T07:43:15.2036920Z [1m[92m   Compiling[0m futures-macro v0.3.31
2026-07-25T07:43:16.6240900Z [1m[92m   Compiling[0m core-foundation-sys v0.8.7
2026-07-25T07:43:16.9410550Z [1m[92m   Compiling[0m futures-task v0.3.31
2026-07-25T07:43:17.2188520Z [1m[92m   Compiling[0m futures-io v0.3.31
2026-07-25T07:43:17.5104400Z [1m[92m   Compiling[0m rustix v0.38.44
2026-07-25T07:43:18.0944410Z [1m[92m   Compiling[0m zerocopy v0.8.24
2026-07-25T07:43:18.8608230Z [1m[92m   Compiling[0m icu_locid_transform_data v1.5.1
2026-07-25T07:43:19.2351660Z [1m[92m   Compiling[0m regex-syntax v0.8.5
2026-07-25T07:43:25.1173460Z [1m[92m   Compiling[0m smallvec v1.15.0
2026-07-25T07:43:25.6575420Z [1m[92m   Compiling[0m writeable v0.5.5
2026-07-25T07:43:26.5176700Z [1m[92m   Compiling[0m fnv v1.0.7
2026-07-25T07:43:26.6406990Z [1m[92m   Compiling[0m pin-utils v0.1.0
2026-07-25T07:43:26.7585100Z [1m[92m   Compiling[0m litemap v0.7.5
2026-07-25T07:43:27.2539380Z [1m[92m   Compiling[0m icu_locid v1.5.0
2026-07-25T07:43:34.5481510Z [1m[92m   Compiling[0m futures-util v0.3.31
2026-07-25T07:43:42.7706830Z [1m[92m   Compiling[0m http v1.3.1
2026-07-25T07:43:47.7698510Z [1m[92m   Compiling[0m regex-automata v0.4.9
2026-07-25T07:43:56.1772200Z [1m[92m   Compiling[0m crypto-common v0.1.6
2026-07-25T07:43:56.4563210Z [1m[92m   Compiling[0m icu_provider_macros v1.5.0
2026-07-25T07:43:57.2520630Z [1m[92m   Compiling[0m zeroize_derive v1.4.2
2026-07-25T07:43:58.3816440Z [1m[92m   Compiling[0m ring v0.17.14
2026-07-25T07:43:59.3515110Z [1m[92m   Compiling[0m atty v0.2.14
2026-07-25T07:43:59.4791120Z [1m[92m   Compiling[0m icu_properties_data v1.5.1
2026-07-25T07:43:59.8317030Z [1m[92m   Compiling[0m minimal-lexical v0.2.1
2026-07-25T07:44:00.3150030Z [1m[92m   Compiling[0m unicode-width v0.1.14
2026-07-25T07:44:01.0278970Z [1m[92m   Compiling[0m aws-lc-rs v1.13.0
2026-07-25T07:44:01.4754630Z [1m[92m   Compiling[0m textwrap v0.11.0
2026-07-25T07:44:01.8094590Z [1m[92m   Compiling[0m nom v7.1.3
2026-07-25T07:44:09.4599490Z [1m[92m   Compiling[0m zeroize v1.8.1
2026-07-25T07:44:09.8433970Z [1m[92m   Compiling[0m icu_provider v1.5.0
2026-07-25T07:44:19.9969720Z [1m[92m   Compiling[0m regex v1.11.1
2026-07-25T07:44:20.7243750Z [1m[92m   Compiling[0m libloading v0.8.6
2026-07-25T07:44:20.7621970Z [1m[92m   Compiling[0m tracing-core v0.1.33
2026-07-25T07:44:20.9590130Z [1m[92m   Compiling[0m rustls-pki-types v1.11.0
2026-07-25T07:44:22.3135910Z [1m[92m   Compiling[0m ansi_term v0.12.1
2026-07-25T07:44:22.6145410Z [1m[92m   Compiling[0m strsim v0.8.0
2026-07-25T07:44:22.7983290Z [1m[92m   Compiling[0m icu_normalizer_data v1.5.1
2026-07-25T07:44:22.9060020Z [1m[92m   Compiling[0m humantime v2.2.0
2026-07-25T07:44:23.0923040Z [1m[92m   Compiling[0m powerfmt v0.2.0
2026-07-25T07:44:23.2336480Z [1m[92m   Compiling[0m bitflags v1.3.2
2026-07-25T07:44:23.3117360Z [1m[92m   Compiling[0m either v1.15.0
2026-07-25T07:44:23.5115960Z [1m[92m   Compiling[0m utf8parse v0.2.2
2026-07-25T07:44:23.6274990Z [1m[92m   Compiling[0m syn v1.0.109
2026-07-25T07:44:23.6529290Z [1m[92m   Compiling[0m termcolor v1.4.1
2026-07-25T07:44:24.0783560Z [1m[92m   Compiling[0m httparse v1.10.1
2026-07-25T07:44:24.2043670Z [1m[92m   Compiling[0m vec_map v0.8.2
2026-07-25T07:44:24.4523470Z [1m[92m   Compiling[0m bindgen v0.59.2
2026-07-25T07:44:24.8654770Z [1m[92m   Compiling[0m getrandom v0.3.2
2026-07-25T07:44:25.2040660Z [1m[92m   Compiling[0m home v0.5.11
2026-07-25T07:44:25.3242440Z [1m[92m   Compiling[0m which v4.4.2
2026-07-25T07:44:25.3963270Z [1m[92m   Compiling[0m clap v2.34.0
2026-07-25T07:44:25.7257540Z [1m[92m   Compiling[0m env_logger v0.9.3
2026-07-25T07:44:26.5101380Z [1m[92m   Compiling[0m anstyle-parse v0.2.6
2026-07-25T07:44:26.8044740Z [1m[92m   Compiling[0m deranged v0.4.0
2026-07-25T07:44:28.2623160Z [1m[92m   Compiling[0m tracing v0.1.41
2026-07-25T07:44:30.6413650Z [1m[92m   Compiling[0m icu_locid_transform v1.5.0
2026-07-25T07:44:35.4845040Z [1m[92m   Compiling[0m ppv-lite86 v0.2.21
2026-07-25T07:44:36.2692310Z [1m[92m   Compiling[0m cexpr v0.6.0
2026-07-25T07:44:37.3456980Z [1m[92m   Compiling[0m http-body v1.0.1
2026-07-25T07:44:37.4444620Z [1m[92m   Compiling[0m tokio-util v0.7.14
2026-07-25T07:44:37.5400410Z [1m[92m   Compiling[0m icu_collections v1.5.0
2026-07-25T07:44:39.0048410Z [1m[92m   Compiling[0m block-buffer v0.10.4
2026-07-25T07:44:39.1915130Z [1m[92m   Compiling[0m peeking_take_while v0.1.2
2026-07-25T07:44:39.2792600Z [1m[92m   Compiling[0m untrusted v0.9.0
2026-07-25T07:44:39.4335370Z [1m[92m   Compiling[0m anstyle v1.0.10
2026-07-25T07:44:39.6027930Z [1m[92m   Compiling[0m lazycell v1.3.0
2026-07-25T07:44:39.7183200Z [1m[92m   Compiling[0m num-conv v0.1.0
2026-07-25T07:44:39.8401760Z [1m[92m   Compiling[0m is_terminal_polyfill v1.70.1
2026-07-25T07:44:39.9013880Z [1m[92m   Compiling[0m atomic-waker v1.1.2
2026-07-25T07:44:39.9328010Z [1m[92m   Compiling[0m lazy_static v1.5.0
2026-07-25T07:44:40.0232860Z [1m[92m   Compiling[0m anstyle-query v1.1.2
2026-07-25T07:44:40.0781840Z [1m[92m   Compiling[0m try-lock v0.2.5
2026-07-25T07:44:40.1714690Z [1m[92m   Compiling[0m rustc-hash v1.1.0
2026-07-25T07:44:40.2015730Z [1m[92m   Compiling[0m time-core v0.1.4
2026-07-25T07:44:40.2696320Z [1m[92m   Compiling[0m colorchoice v1.0.3
2026-07-25T07:44:40.3376800Z [1m[92m   Compiling[0m time v0.3.41
2026-07-25T07:44:40.3985460Z [1m[92m   Compiling[0m anstream v0.6.18
2026-07-25T07:44:50.3327690Z [1m[92m   Compiling[0m want v0.3.1
2026-07-25T07:44:50.5800880Z [1m[92m   Compiling[0m h2 v0.4.8
2026-07-25T07:45:00.6689420Z [1m[92m   Compiling[0m digest v0.10.7
2026-07-25T07:45:01.3182440Z [1m[92m   Compiling[0m icu_properties v1.5.1
2026-07-25T07:45:08.9251720Z [1m[92m   Compiling[0m security-framework-sys v2.14.0
2026-07-25T07:45:09.1490310Z [1m[92m   Compiling[0m core-foundation v0.9.4
2026-07-25T07:45:10.0916520Z [1m[92m   Compiling[0m zstd-sys v2.0.15+zstd.1.5.7
2026-07-25T07:45:10.6195330Z [1m[92m   Compiling[0m openssl-src v300.6.0+3.6.2
2026-07-25T07:45:11.0487470Z [1m[92m   Compiling[0m autotools v0.2.7
2026-07-25T07:45:11.4001050Z [1m[92m   Compiling[0m tower-service v0.3.3
2026-07-25T07:45:11.4977920Z [1m[92m   Compiling[0m native-tls v0.2.14
2026-07-25T07:45:11.8241140Z [1m[92m   Compiling[0m write16 v1.0.0
2026-07-25T07:45:12.4213590Z [1m[92m   Compiling[0m vcpkg v0.2.15
2026-07-25T07:45:13.5276780Z [1m[92m   Compiling[0m base64 v0.22.1
2026-07-25T07:45:14.2411210Z [1m[92m   Compiling[0m utf16_iter v1.0.5
2026-07-25T07:45:14.4338360Z [1m[92m   Compiling[0m utf8_iter v1.0.4
2026-07-25T07:45:14.6011800Z [1m[92m   Compiling[0m rustls v0.23.26
2026-07-25T07:45:14.6737980Z [1m[92m   Compiling[0m rustix v1.0.5
2026-07-25T07:45:14.9313110Z [1m[92m   Compiling[0m icu_normalizer v1.5.0
2026-07-25T07:45:15.3845570Z [1m[92m   Compiling[0m openssl-sys v0.9.107
2026-07-25T07:45:16.2361550Z [1m[92m   Compiling[0m swift-bridge-ir v0.1.56 (https://github.com/naturecodevoid/swift-bridge#cc1e577d)
2026-07-25T07:45:22.7982670Z [1m[92m   Compiling[0m security-framework v2.11.1
2026-07-25T07:45:26.4374040Z [1m[92m   Compiling[0m hyper v1.6.0
2026-07-25T07:45:33.2637760Z [1m[92m   Compiling[0m rustls-webpki v0.103.1
2026-07-25T07:45:46.7882600Z [1m[92m   Compiling[0m quick-xml v0.32.0
2026-07-25T07:45:50.5042710Z [1m[92m   Compiling[0m cpufeatures v0.2.17
2026-07-25T07:45:50.6555980Z [1m[92m   Compiling[0m strsim v0.11.1
2026-07-25T07:45:52.4144270Z [1m[92m   Compiling[0m heck v0.5.0
2026-07-25T07:45:55.1058950Z [1m[92m   Compiling[0m thiserror v2.0.12
2026-07-25T07:45:55.6313520Z [1m[92m   Compiling[0m clap_lex v0.7.4
2026-07-25T07:45:56.4135640Z [1m[92m   Compiling[0m percent-encoding v2.3.1
2026-07-25T07:45:56.9358020Z [1m[92m   Compiling[0m form_urlencoded v1.2.1
2026-07-25T07:45:57.4450950Z [1m[92m   Compiling[0m clap_builder v4.5.36
2026-07-25T07:46:19.3730620Z [1m[92m   Compiling[0m clap_derive v4.5.32
2026-07-25T07:46:22.7751920Z [1m[92m   Compiling[0m plist v1.7.1
2026-07-25T07:46:29.8883690Z [1m[92m   Compiling[0m hyper-util v0.1.11
2026-07-25T07:47:19.9771340Z [1m[92m   Compiling[0m idna_adapter v1.2.0
2026-07-25T07:47:22.7890020Z [1m[92m   Compiling[0m rand_core v0.6.4
2026-07-25T07:47:23.2337930Z [1m[92m   Compiling[0m thiserror-impl v2.0.12
2026-07-25T07:47:26.5573610Z [1m[92m   Compiling[0m num-traits v0.2.19
2026-07-25T07:47:26.9021640Z [1m[92m   Compiling[0m lzma-sys v0.1.20
2026-07-25T07:47:27.6137510Z [1m[92m   Compiling[0m bzip2-sys v0.1.13+1.0.8
2026-07-25T07:47:28.4564210Z [1m[92m   Compiling[0m ryu v1.0.20
2026-07-25T07:47:29.2180920Z [1m[92m   Compiling[0m fastrand v2.3.0
2026-07-25T07:47:29.6524800Z [1m[92m   Compiling[0m serde_json v1.0.140
2026-07-25T07:47:29.9837070Z [1m[92m   Compiling[0m zstd-safe v7.2.4
2026-07-25T07:47:30.5034570Z [1m[92m   Compiling[0m tempfile v3.19.1
2026-07-25T07:47:53.4653760Z [1m[92m   Compiling[0m rand_chacha v0.3.1
2026-07-25T07:47:58.3343350Z [1m[92m   Compiling[0m idna v1.0.3
2026-07-25T07:48:02.4827930Z [1m[92m   Compiling[0m tokio-rustls v0.26.2
2026-07-25T07:48:03.0113160Z [1m[92m   Compiling[0m tokio-native-tls v0.3.1
2026-07-25T07:48:03.2430760Z [1m[92m   Compiling[0m clap v4.5.36
2026-07-25T07:48:05.6812140Z [1m[92m   Compiling[0m plist_plus v0.2.6 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/plist_plus)
2026-07-25T07:48:06.2899020Z [1m[92m   Compiling[0m rand_core v0.9.3
2026-07-25T07:48:06.6705600Z [1m[92m   Compiling[0m http-body-util v0.1.3
2026-07-25T07:48:07.1517730Z [1m[92m   Compiling[0m webpki-roots v0.26.8
2026-07-25T07:48:07.3153610Z [1m[92m   Compiling[0m inout v0.1.4
2026-07-25T07:48:07.5041100Z [1m[92m   Compiling[0m sync_wrapper v1.0.2
2026-07-25T07:48:07.6307650Z [1m[92m   Compiling[0m crc32fast v1.4.2
2026-07-25T07:48:07.9804020Z [1m[92m   Compiling[0m tower-layer v0.3.3
2026-07-25T07:48:08.2919210Z [1m[92m   Compiling[0m byteorder v1.5.0
2026-07-25T07:48:08.7118390Z [1m[92m   Compiling[0m foreign-types-shared v0.1.1
2026-07-25T07:48:08.7925360Z [1m[92m   Compiling[0m crc-catalog v2.4.0
2026-07-25T07:48:08.8982960Z [1m[92m   Compiling[0m adler2 v2.0.0
2026-07-25T07:48:09.0852140Z [1m[92m   Compiling[0m openssl v0.10.72
2026-07-25T07:48:09.4334510Z [1m[92m   Compiling[0m miniz_oxide v0.8.8
2026-07-25T07:48:12.1463970Z [1m[92m   Compiling[0m crc v3.2.1
2026-07-25T07:48:13.7420760Z [1m[92m   Compiling[0m foreign-types v0.3.2
2026-07-25T07:48:13.8136070Z [1m[92m   Compiling[0m tower v0.5.2
2026-07-25T07:48:14.5410390Z [1m[92m   Compiling[0m cipher v0.4.4
2026-07-25T07:48:14.8850520Z [1m[92m   Compiling[0m hyper-rustls v0.27.5
2026-07-25T07:48:15.7792710Z [1m[92m   Compiling[0m hyper-tls v0.6.0
2026-07-25T07:48:16.1193090Z [1m[92m   Compiling[0m rand_chacha v0.9.0
2026-07-25T07:49:19.9585460Z [1m[92m   Compiling[0m env_filter v0.1.3
2026-07-25T07:49:21.5437000Z [1m[92m   Compiling[0m nskeyedarchiver_converter v0.1.2
2026-07-25T07:49:25.5803760Z [1m[92m   Compiling[0m url v2.5.4
2026-07-25T07:49:29.9613090Z [1m[92m   Compiling[0m rand v0.8.5
2026-07-25T07:49:34.4652690Z [1m[92m   Compiling[0m swift-bridge-build v0.1.56 (https://github.com/naturecodevoid/swift-bridge#cc1e577d)
2026-07-25T07:49:39.7162220Z [1m[92m   Compiling[0m serde_urlencoded v0.7.1
2026-07-25T07:49:40.1205950Z [1m[92m   Compiling[0m rusty_libimobiledevice v0.1.7 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/rusty_libimobiledevice)
2026-07-25T07:49:40.7568650Z [1m[92m   Compiling[0m hmac v0.12.1
2026-07-25T07:49:40.9302680Z [1m[92m   Compiling[0m rustls-pemfile v2.2.0
2026-07-25T07:49:41.2650400Z [1m[92m   Compiling[0m futures-executor v0.3.31
2026-07-25T07:49:41.9378230Z [1m[92m   Compiling[0m iana-time-zone v0.1.63
2026-07-25T07:49:42.1347960Z [1m[92m   Compiling[0m openssl-macros v0.1.1
2026-07-25T07:49:42.5577820Z [1m[92m   Compiling[0m encoding_rs v0.8.35
2026-07-25T07:49:51.9588490Z [1m[92m   Compiling[0m simd-adler32 v0.3.7
2026-07-25T07:49:53.6559150Z [1m[92m   Compiling[0m ipnet v2.11.0
2026-07-25T07:49:56.5733900Z [1m[92m   Compiling[0m lockfree-object-pool v0.1.6
2026-07-25T07:49:56.8551200Z [1m[92m   Compiling[0m zip v2.6.1
2026-07-25T07:49:57.2163560Z [1m[92m   Compiling[0m mime v0.3.17
2026-07-25T07:49:58.1980520Z [1m[92m   Compiling[0m bumpalo v3.17.0
2026-07-25T07:49:58.6952800Z [1m[92m   Compiling[0m jiff v0.2.8
2026-07-25T07:50:23.6130840Z [1m[92m   Compiling[0m env_logger v0.11.8
2026-07-25T07:50:25.8306540Z [1m[92m   Compiling[0m zopfli v0.8.1
2026-07-25T07:50:29.3313750Z [1m[92m   Compiling[0m reqwest v0.12.15
2026-07-25T07:51:03.0399460Z [1m[92m   Compiling[0m chrono v0.4.40
2026-07-25T07:51:10.2581210Z [1m[92m   Compiling[0m futures v0.3.31
2026-07-25T07:51:10.3644010Z [1m[92m   Compiling[0m pbkdf2 v0.12.2
2026-07-25T07:53:11.1662220Z [1m[91merror[0m: failed to run custom build command for `rusty_libimobiledevice v0.1.7 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/rusty_libimobiledevice)`
2026-07-25T07:53:11.1669370Z 
2026-07-25T07:53:11.1689420Z Caused by:
2026-07-25T07:53:11.1806920Z   process didn't exit successfully: `/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/release/build/rusty_libimobiledevice-3bc978768e46d37f/build-script-build` (exit status: 101)
2026-07-25T07:53:11.1834240Z   --- stdout
2026-07-25T07:53:11.1902230Z   cargo:rerun-if-changed=wrapper.h
2026-07-25T07:53:11.1910660Z   cargo:rerun-if-changed=build.rs
2026-07-25T07:53:11.1937170Z   cargo:rustc-link-search=native=/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/openssl-sys-3f7abc064d2337f5/out/openssl-build/install/lib
2026-07-25T07:53:11.2031870Z 
2026-07-25T07:53:11.2043240Z   --- stderr
2026-07-25T07:53:11.2045260Z 
2026-07-25T07:53:11.2050010Z   thread 'main' (502635) panicked at /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/rusty_libimobiledevice/build.rs:95:34:
2026-07-25T07:53:11.2079620Z   called `Result::unwrap()` on an `Err` value: Os { code: 2, kind: NotFound, message: "No such file or directory" }
2026-07-25T07:53:11.2085350Z   note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
2026-07-25T07:53:11.2087780Z [1m[33mwarning[0m: build failed, waiting for other jobs to finish...
2026-07-25T07:53:18.3414250Z make: *** [xcgen] Error 101
2026-07-25T07:53:18.3466090Z ##[error]Process completed with exit code 2.
2026-07-25T07:53:18.3772140Z ##[group]Run set -euo pipefail
2026-07-25T07:53:18.3773180Z [36;1mset -euo pipefail[0m
2026-07-25T07:53:18.3773730Z [36;1mmkdir -p build-diagnostics[0m
2026-07-25T07:53:18.3774300Z [36;1m{[0m
2026-07-25T07:53:18.3774780Z [36;1m  echo '# AlleyCat unsigned IPA failure'[0m
2026-07-25T07:53:18.3775420Z [36;1m  echo[0m
2026-07-25T07:53:18.3776030Z [36;1m  echo "- Run: $GITHUB_RUN_ID"[0m
2026-07-25T07:53:18.3776660Z [36;1m  echo "- Commit: $GITHUB_SHA"[0m
2026-07-25T07:53:18.3778080Z [36;1m  echo '- Workflow: ios-unsigned-ipa.yml'[0m
2026-07-25T07:53:18.3778800Z [36;1m  echo "- Rust cache hit: true"[0m
2026-07-25T07:53:18.3779490Z [36;1m  for log in runtime-build xcodebuild; do[0m
2026-07-25T07:53:18.3780150Z [36;1m    echo[0m
2026-07-25T07:53:18.3780590Z [36;1m    echo "## $log tail"[0m
2026-07-25T07:53:18.3781140Z [36;1m    echo '```text'[0m
2026-07-25T07:53:18.3781810Z [36;1m    tail -n 500 "build/logs/$log.log" 2>/dev/null || true[0m
2026-07-25T07:53:18.3782630Z [36;1m    echo '```'[0m
2026-07-25T07:53:18.3783100Z [36;1m  done[0m
2026-07-25T07:53:18.3783670Z [36;1m} > build-diagnostics/alleycat-ios-last-error.md[0m
2026-07-25T07:53:18.3784640Z [36;1mgit config user.name github-actions[bot][0m
2026-07-25T07:53:18.3785740Z [36;1mgit config user.email 41898282+github-actions[bot]@users.noreply.github.com[0m
2026-07-25T07:53:18.3786940Z [36;1mgit add build-diagnostics/alleycat-ios-last-error.md[0m
2026-07-25T07:53:18.3788000Z [36;1mgit commit -m 'Record AlleyCat IPA failure [skip ci]' || exit 0[0m
2026-07-25T07:53:18.3788910Z [36;1mgit pull --rebase origin main[0m
2026-07-25T07:53:18.3789540Z [36;1mgit push origin HEAD:main[0m
2026-07-25T07:53:18.4281880Z shell: /bin/bash -e {0}
2026-07-25T07:53:18.4282590Z env:
2026-07-25T07:53:18.4283070Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T07:53:18.4283770Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T07:53:18.4284340Z   CARGO_INCREMENTAL: 0
2026-07-25T07:53:18.4284830Z   CARGO_BUILD_JOBS: 2
2026-07-25T07:53:18.4312110Z   CARGO_NET_RETRY: 10
2026-07-25T07:53:18.4312750Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T07:53:18.4313370Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T07:53:18.4314020Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T07:53:18.4314630Z   IOS_MIN: 16.1
2026-07-25T07:53:18.4315090Z   RUSTC_WRAPPER: 
2026-07-25T07:53:18.4315570Z   SCCACHE_DISABLE: 1
2026-07-25T07:53:18.4316090Z   SOURCE_ROOT: upstream/litter
2026-07-25T07:53:18.4317130Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T07:53:18.4318630Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T07:53:18.4319760Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T07:53:18.4321330Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T07:53:18.4322380Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T07:53:18.4323250Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T07:53:18.4324240Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T07:53:18.4324950Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T07:53:18.4325700Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T07:53:18.4326600Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T07:53:18.4327340Z   CARGO_TERM_COLOR: always
2026-07-25T07:53:18.4328310Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T07:53:18.4330000Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T07:53:18.4332310Z ##[endgroup]
2026-07-25T07:53:20.0357110Z [main 6169a1c] Record AlleyCat IPA failure [skip ci]
2026-07-25T07:53:20.0360620Z  1 file changed, 2 insertions(+), 2 deletions(-)
2026-07-25T07:53:21.3631790Z From https://github.com/NightVibes33/Codex-DEB-Test
2026-07-25T07:53:21.3635360Z  * branch            main       -> FETCH_HEAD
2026-07-25T07:53:21.3638650Z    ec8d9ed..02b7b8f  main       -> origin/main
2026-07-25T07:53:21.6593900Z Rebasing (1/1)
2026-07-25T07:53:21.6595180Z Successfully rebased and updated refs/heads/main.
2026-07-25T07:53:23.0447380Z To https://github.com/NightVibes33/Codex-DEB-Test
2026-07-25T07:53:23.0449050Z    02b7b8f..38e9d49  HEAD -> main
2026-07-25T07:53:23.0753220Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T07:53:23.0758750Z ##[group]Run actions/upload-artifact@v4
2026-07-25T07:53:23.0759660Z with:
2026-07-25T07:53:23.0760300Z   name: AlleyCat-IPA-Build-Logs-30149054628
2026-07-25T07:53:23.0761200Z   path: build/logs/
build-diagnostics/

2026-07-25T07:53:23.0762220Z   if-no-files-found: warn
2026-07-25T07:53:23.0762910Z   compression-level: 6
2026-07-25T07:53:23.0763550Z   overwrite: false
2026-07-25T07:53:23.0764230Z   include-hidden-files: false
2026-07-25T07:53:23.0764910Z env:
2026-07-25T07:53:23.0765500Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T07:53:23.0766340Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T07:53:23.0767080Z   CARGO_INCREMENTAL: 0
2026-07-25T07:53:23.0767850Z   CARGO_BUILD_JOBS: 2
2026-07-25T07:53:23.0768480Z   CARGO_NET_RETRY: 10
2026-07-25T07:53:23.0769100Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T07:53:23.0769850Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T07:53:23.0770650Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T07:53:23.0771520Z   IOS_MIN: 16.1
2026-07-25T07:53:23.0772100Z   RUSTC_WRAPPER: 
2026-07-25T07:53:23.0772850Z   SCCACHE_DISABLE: 1
2026-07-25T07:53:23.0773480Z   SOURCE_ROOT: upstream/litter
2026-07-25T07:53:23.0774670Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T07:53:23.0776110Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T07:53:23.0777140Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T07:53:23.0778390Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T07:53:23.0779240Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T07:53:23.0780030Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T07:53:23.0781200Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T07:53:23.0782390Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T07:53:23.0783600Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T07:53:23.0784860Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T07:53:23.0785890Z   CARGO_TERM_COLOR: always
2026-07-25T07:53:23.0787940Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T07:53:23.0790170Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T07:53:23.0791810Z ##[endgroup]
2026-07-25T07:53:23.5607230Z (node:44550) [DEP0040] DeprecationWarning: The `punycode` module is deprecated. Please use a userland alternative instead.
2026-07-25T07:53:23.5658800Z (Use `node --trace-deprecation ...` to show where the warning was created)
2026-07-25T07:53:23.5786240Z Multiple search paths detected. Calculating the least common ancestor of all paths
2026-07-25T07:53:23.5794090Z The least common ancestor is /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test. This will be the root directory of the artifact
2026-07-25T07:53:23.5798170Z With the provided path, there will be 8 files uploaded
2026-07-25T07:53:23.5803990Z Artifact name is valid!
2026-07-25T07:53:23.5806000Z Root directory input is valid!
2026-07-25T07:53:23.7509090Z Beginning upload of artifact content to blob storage
2026-07-25T07:53:23.8381810Z (node:44550) [DEP0169] DeprecationWarning: `url.parse()` behavior is not standardized and prone to errors that have security implications. Use the WHATWG URL API instead. CVEs are not issued for `url.parse()` vulnerabilities.
2026-07-25T07:53:23.8934430Z Uploaded bytes 18823
2026-07-25T07:53:23.9179810Z Finished uploading artifact content to blob storage!
2026-07-25T07:53:23.9182180Z SHA256 digest of uploaded artifact zip is a1ade76118358f1fff7b9cdf09319be8174eec48638549479d59287dcae3e309
2026-07-25T07:53:23.9184740Z Finalizing artifact upload
2026-07-25T07:53:24.0761430Z Artifact AlleyCat-IPA-Build-Logs-30149054628.zip successfully finalized. Artifact ID 8617346112
2026-07-25T07:53:24.0766980Z Artifact AlleyCat-IPA-Build-Logs-30149054628 has been successfully uploaded! Final size is 18823 bytes. Artifact ID is 8617346112
2026-07-25T07:53:24.0783040Z Artifact download URL: https://github.com/NightVibes33/Codex-DEB-Test/actions/runs/30149054628/artifacts/8617346112
2026-07-25T07:53:24.1443650Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T07:53:24.1451510Z Post job cleanup.
2026-07-25T07:53:25.4660030Z Zig cache directory is inaccessible; nothing to save
2026-07-25T07:53:25.5249330Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T07:53:25.5254650Z Post job cleanup.
2026-07-25T07:53:25.8043000Z [command]/usr/local/bin/git version
2026-07-25T07:53:25.8210610Z git version 2.55.0
2026-07-25T07:53:25.8281460Z Copying '/Users/runner/.gitconfig' to '/Users/runner/work/_temp/1d415769-11c7-4993-a279-7eb7b65b5255/.gitconfig'
2026-07-25T07:53:25.8312030Z Temporarily overriding HOME='/Users/runner/work/_temp/1d415769-11c7-4993-a279-7eb7b65b5255' before making global git config changes
2026-07-25T07:53:25.8315210Z Adding repository directory to the temporary git global config as a safe directory
2026-07-25T07:53:25.8333630Z [command]/usr/local/bin/git config --global --add safe.directory /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test
2026-07-25T07:53:25.8608280Z [command]/usr/local/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-07-25T07:53:25.8785250Z [command]/usr/local/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-07-25T07:53:26.1766970Z [command]/usr/local/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-07-25T07:53:26.1926560Z http.https://github.com/.extraheader
2026-07-25T07:53:26.1967240Z [command]/usr/local/bin/git config --local --unset-all http.https://github.com/.extraheader
2026-07-25T07:53:26.2151990Z [command]/usr/local/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-07-25T07:53:26.4273000Z [command]/usr/local/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-07-25T07:53:26.4421520Z [command]/usr/local/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-07-25T07:53:26.6679170Z Cleaning up orphan processes
2026-07-25T07:53:27.3080220Z ##[warning]Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on Node.js 24: actions/cache/restore@v4, actions/cache@v4, actions/checkout@v4, actions/upload-artifact@v4, mlugg/setup-zig@v2. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
```
