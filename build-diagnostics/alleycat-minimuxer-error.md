# AlleyCat minimuxer failure

- Job: 89651432379

```text
402:2026-07-25T06:19:47.4125340Z Cache not found for input keys: homebrew-ios-macOS-xcodegen-native-tools-v5
979:2026-07-25T06:20:33.0276290Z Cache not found for input keys: ios-cargo-registry-macOS-e692f0ec6f47c79c4db217a3ee6814d0de586a9b0c9fae863006aa632720cf44, ios-cargo-registry-macOS-
1020:2026-07-25T06:20:33.7908940Z Cache not found for input keys: alleycat-zig-global-macOS-11411bc7bd232219d842d100dd6e83c227f47e0f18bca5c5ac68694a6980c49a, alleycat-zig-global-macOS-
1061:2026-07-25T06:20:34.5357300Z Cache not found for input keys: rusty-v8-149.2.0-macOS-x86_64-apple-darwin, rusty-v8-149.2.0-macOS-
1263:2026-07-25T06:21:40.7418960Z Cache not found for input keys: ios-alpine-fs-v1-macOS-470f63b1d69d52a48a62bdead0e7425c28c071f76b05833a873eb87167f432ac, ios-alpine-fs-v1-macOS-
1317:2026-07-25T06:21:45.1571810Z ==> Building KittyStore minimuxer Rust bridge for full AlleyCat sideload build
1384:2026-07-25T06:23:14.3664280Z For cmake to find llvm you may need to set:
1385:2026-07-25T06:23:14.3665700Z   export CMAKE_PREFIX_PATH="/usr/local/opt/llvm"
1422:2026-07-25T06:23:14.7801580Z For cmake to find llvm you may need to set:
1423:2026-07-25T06:23:14.7802430Z   export CMAKE_PREFIX_PATH="/usr/local/opt/llvm"
1424:2026-07-25T06:23:19.7853130Z ==> Using iOS deployment target 18.0 for KittyStore minimuxer Rust libraries
1425:2026-07-25T06:23:19.7862830Z ==> Installing bindgen-cli for aws-lc-sys
1428:2026-07-25T06:23:20.3249500Z [1m[92m  Downloaded[0m bindgen-cli v0.69.5
1429:2026-07-25T06:23:20.4012910Z [1m[92m  Installing[0m bindgen-cli v0.69.5
1472:2026-07-25T06:23:21.4692930Z [1m[92m  Downloaded[0m bindgen v0.69.5
1514:2026-07-25T06:23:55.0697060Z [1m[92m   Compiling[0m bindgen v0.69.5
1531:2026-07-25T06:25:11.8618140Z [1m[92m   Compiling[0m bindgen-cli v0.69.5
1533:2026-07-25T06:25:20.8835750Z [1m[92m  Installing[0m /Users/runner/.cargo/bin/bindgen
1534:2026-07-25T06:25:20.8844490Z [1m[92m   Installed[0m package `bindgen-cli v0.69.5` (executable `bindgen`)
1536:2026-07-25T06:25:21.1164650Z ==> Building KittyStore RustBridge for iOS device
1547:2026-07-25T06:25:23.9148870Z [1m[92m  Downloaded[0m aws-lc-rs v1.16.2
1626:2026-07-25T06:25:26.1210850Z [1m[92m  Downloaded[0m bindgen v0.59.2
1630:2026-07-25T06:25:26.2183580Z [1m[92m  Downloaded[0m aws-lc-sys v0.39.1
1738:2026-07-25T06:25:29.5353580Z [1m[92m  Downloaded[0m cmake v0.1.57
1819:2026-07-25T06:25:45.8246840Z [1m[92m   Compiling[0m cmake v0.1.57
1844:2026-07-25T06:26:12.2909340Z [1m[92m   Compiling[0m aws-lc-sys v0.39.1
1867:2026-07-25T06:26:33.0100700Z [1m[92m   Compiling[0m bindgen v0.59.2
1904:2026-07-25T06:27:00.3605190Z [1m[92m   Compiling[0m aws-lc-rs v1.16.2
2029:2026-07-25T06:30:23.9339720Z [1m[92m   Compiling[0m rust_bridge v1.0.0 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/Source/Dependencies/minimuxer/RustBridge)
2031:2026-07-25T06:31:07.7654520Z ==> Building KittyStore minimuxer for iOS device
2045:2026-07-25T06:31:09.3732590Z [1m[92m  Downloaded[0m aws-lc-sys v0.28.0
2070:2026-07-25T06:31:10.3451110Z [1m[92m  Downloaded[0m openssl-macros v0.1.1
2103:2026-07-25T06:31:10.8547150Z [1m[92m  Downloaded[0m cmake v0.1.54
2120:2026-07-25T06:31:11.1443420Z [1m[92m  Downloaded[0m aws-lc-rs v1.13.0
2157:2026-07-25T06:31:11.7570210Z [1m[92m  Downloaded[0m openssl-sys v0.9.107
2178:2026-07-25T06:31:12.2346480Z [1m[92m  Downloaded[0m openssl v0.10.72
2214:2026-07-25T06:31:12.8740090Z [1m[92m  Downloaded[0m openssl-src v300.6.0+3.6.2
2240:2026-07-25T06:31:25.7090040Z [1m[92m   Compiling[0m cmake v0.1.54
2270:2026-07-25T06:31:40.8143520Z [1m[92m   Compiling[0m aws-lc-sys v0.28.0
2301:2026-07-25T06:32:31.8330580Z [1m[92m   Compiling[0m aws-lc-rs v1.13.0
2312:2026-07-25T06:32:45.1907070Z [1m[92m   Compiling[0m bindgen v0.59.2
2362:2026-07-25T06:33:22.6205790Z [1m[92m   Compiling[0m openssl-src v300.6.0+3.6.2
2373:2026-07-25T06:33:26.1419430Z [1m[92m   Compiling[0m openssl-sys v0.9.107
2414:2026-07-25T06:35:30.2889120Z [1m[92m   Compiling[0m openssl v0.10.72
2428:2026-07-25T06:35:48.5314530Z [1m[91merror[0m: failed to run custom build command for `plist_plus v0.2.6 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/plist_plus)`
2431:2026-07-25T06:35:48.5318850Z   process didn't exit successfully: `/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/release/build/plist_plus-241040c3fb6e2ada/build-script-build` (exit status: 101)
2435:2026-07-25T06:35:48.5347130Z   running: cd "/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/build" && AR="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar" CC="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" CFLAGS="-O3 -fPIC --target=arm64-apple-ios -miphoneos-version-min=18.0 -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0  -std=gnu17" CPP="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -E --target=arm64-apple-ios -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0" CXX="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++" CXXCPP="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ -E --target=arm64-apple-ios -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0" CXXFLAGS="-O3 -fPIC --target=arm64-apple-ios -miphoneos-version-min=18.0 -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0" LC_ALL="C" RANLIB="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" ac_cv_c_undeclared_builtin_options="-fno-builtin" "sh" "-c" "exec \"$0\" \"$@\"" "/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/libplist/configure" "--prefix=/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out" "--disable-shared" "--enable-static" "--without-cython" "--host=aarch64-apple-darwin"
2439:2026-07-25T06:35:48.5371010Z   /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/libplist/configure: line 2650: syntax error near unexpected token `dist-bzip2'
2440:2026-07-25T06:35:48.5374960Z   /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/libplist/configure: line 2650: `AM_INIT_AUTOMAKE(dist-bzip2 no-dist-gzip check-news)'
2446:2026-07-25T06:35:48.5380060Z   build script failed, must exit now
2448:2026-07-25T06:35:48.5382070Z [1m[33mwarning[0m: build failed, waiting for other jobs to finish...
2450:2026-07-25T06:37:29.7769040Z ##[error]Process completed with exit code 2.

--- final 350 lines ---
2026-07-25T06:31:24.3918710Z [1m[92m   Compiling[0m autocfg v1.4.0
2026-07-25T06:31:24.8886140Z [1m[92m   Compiling[0m synstructure v0.13.1
2026-07-25T06:31:25.6312580Z [1m[92m   Compiling[0m pin-project-lite v0.2.16
2026-07-25T06:31:25.7090040Z [1m[92m   Compiling[0m cmake v0.1.54
2026-07-25T06:31:26.0424170Z [1m[92m   Compiling[0m serde_derive v1.0.219
2026-07-25T06:31:26.2281570Z [1m[92m   Compiling[0m zerofrom-derive v0.1.6
2026-07-25T06:31:28.0045510Z [1m[92m   Compiling[0m futures-core v0.3.31
2026-07-25T06:31:28.1531960Z [1m[92m   Compiling[0m once_cell v1.21.3
2026-07-25T06:31:28.4349090Z [1m[92m   Compiling[0m bytes v1.10.1
2026-07-25T06:31:30.2941970Z [1m[92m   Compiling[0m typenum v1.18.0
2026-07-25T06:31:30.6681480Z [1m[92m   Compiling[0m version_check v0.9.5
2026-07-25T06:31:30.9763600Z [1m[92m   Compiling[0m generic-array v0.14.7
2026-07-25T06:31:31.2047690Z [1m[92m   Compiling[0m zerofrom v0.1.6
2026-07-25T06:31:31.3320260Z [1m[92m   Compiling[0m yoke-derive v0.7.5
2026-07-25T06:31:32.5738660Z [1m[92m   Compiling[0m errno v0.3.11
2026-07-25T06:31:32.7390010Z [1m[92m   Compiling[0m stable_deref_trait v1.2.0
2026-07-25T06:31:32.7966200Z [1m[92m   Compiling[0m bitflags v2.9.0
2026-07-25T06:31:33.0064540Z [1m[92m   Compiling[0m yoke v0.7.5
2026-07-25T06:31:34.2806560Z [1m[92m   Compiling[0m zerovec-derive v0.10.3
2026-07-25T06:31:34.9429220Z [1m[92m   Compiling[0m slab v0.4.9
2026-07-25T06:31:35.1017580Z [1m[92m   Compiling[0m hashbrown v0.15.2
2026-07-25T06:31:35.5978440Z [1m[92m   Compiling[0m futures-sink v0.3.31
2026-07-25T06:31:36.0590300Z [1m[92m   Compiling[0m equivalent v1.0.2
2026-07-25T06:31:36.1209130Z [1m[92m   Compiling[0m indexmap v2.9.0
2026-07-25T06:31:36.5101230Z [1m[92m   Compiling[0m zerovec v0.10.4
2026-07-25T06:31:38.2766150Z [1m[92m   Compiling[0m displaydoc v0.2.5
2026-07-25T06:31:38.4320980Z [1m[92m   Compiling[0m tokio-macros v2.5.0
2026-07-25T06:31:38.9854740Z [1m[92m   Compiling[0m getrandom v0.2.15
2026-07-25T06:31:39.1335710Z [1m[92m   Compiling[0m mio v1.0.3
2026-07-25T06:31:39.1801740Z [1m[92m   Compiling[0m socket2 v0.5.9
2026-07-25T06:31:40.4626320Z [1m[92m   Compiling[0m fs_extra v1.3.0
2026-07-25T06:31:40.4996780Z [1m[92m   Compiling[0m dunce v1.0.5
2026-07-25T06:31:40.5687480Z [1m[92m   Compiling[0m log v0.4.27
2026-07-25T06:31:40.8143520Z [1m[92m   Compiling[0m aws-lc-sys v0.28.0
2026-07-25T06:31:40.8834710Z [1m[92m   Compiling[0m tokio v1.44.2
2026-07-25T06:31:41.9117380Z [1m[92m   Compiling[0m glob v0.3.2
2026-07-25T06:31:42.3339380Z [1m[92m   Compiling[0m subtle v2.6.1
2026-07-25T06:31:42.4999300Z [1m[92m   Compiling[0m clang-sys v1.8.1
2026-07-25T06:31:57.5384330Z [1m[92m   Compiling[0m tinystr v0.7.6
2026-07-25T06:31:57.8155090Z [1m[92m   Compiling[0m aho-corasick v1.1.3
2026-07-25T06:32:00.9525990Z [1m[92m   Compiling[0m futures-channel v0.3.31
2026-07-25T06:32:01.2699140Z [1m[92m   Compiling[0m futures-macro v0.3.31
2026-07-25T06:32:02.3392210Z [1m[92m   Compiling[0m fnv v1.0.7
2026-07-25T06:32:02.4359550Z [1m[92m   Compiling[0m smallvec v1.15.0
2026-07-25T06:32:02.7768900Z [1m[92m   Compiling[0m rustix v0.38.44
2026-07-25T06:32:03.1797030Z [1m[92m   Compiling[0m writeable v0.5.5
2026-07-25T06:32:03.8262410Z [1m[92m   Compiling[0m pin-utils v0.1.0
2026-07-25T06:32:03.8897320Z [1m[92m   Compiling[0m core-foundation-sys v0.8.7
2026-07-25T06:32:04.1132880Z [1m[92m   Compiling[0m litemap v0.7.5
2026-07-25T06:32:04.4044510Z [1m[92m   Compiling[0m futures-io v0.3.31
2026-07-25T06:32:04.6040870Z [1m[92m   Compiling[0m icu_locid_transform_data v1.5.1
2026-07-25T06:32:04.8048750Z [1m[92m   Compiling[0m zerocopy v0.8.24
2026-07-25T06:32:05.2024720Z [1m[92m   Compiling[0m regex-syntax v0.8.5
2026-07-25T06:32:09.3283760Z [1m[92m   Compiling[0m futures-task v0.3.31
2026-07-25T06:32:09.5088400Z [1m[92m   Compiling[0m futures-util v0.3.31
2026-07-25T06:32:14.9328240Z [1m[92m   Compiling[0m regex-automata v0.4.9
2026-07-25T06:32:20.3624040Z [1m[92m   Compiling[0m icu_locid v1.5.0
2026-07-25T06:32:25.7252170Z [1m[92m   Compiling[0m http v1.3.1
2026-07-25T06:32:28.5990560Z [1m[92m   Compiling[0m crypto-common v0.1.6
2026-07-25T06:32:28.7158170Z [1m[92m   Compiling[0m zeroize_derive v1.4.2
2026-07-25T06:32:29.3846300Z [1m[92m   Compiling[0m icu_provider_macros v1.5.0
2026-07-25T06:32:30.3441670Z [1m[92m   Compiling[0m ring v0.17.14
2026-07-25T06:32:31.3207980Z [1m[92m   Compiling[0m atty v0.2.14
2026-07-25T06:32:31.4067670Z [1m[92m   Compiling[0m unicode-width v0.1.14
2026-07-25T06:32:31.8330580Z [1m[92m   Compiling[0m aws-lc-rs v1.13.0
2026-07-25T06:32:32.1212320Z [1m[92m   Compiling[0m icu_properties_data v1.5.1
2026-07-25T06:32:32.3598420Z [1m[92m   Compiling[0m minimal-lexical v0.2.1
2026-07-25T06:32:32.7394020Z [1m[92m   Compiling[0m nom v7.1.3
2026-07-25T06:32:36.0464280Z [1m[92m   Compiling[0m textwrap v0.11.0
2026-07-25T06:32:39.5914220Z [1m[92m   Compiling[0m icu_provider v1.5.0
2026-07-25T06:32:40.8137230Z [1m[92m   Compiling[0m zeroize v1.8.1
2026-07-25T06:32:44.4956690Z [1m[92m   Compiling[0m regex v1.11.1
2026-07-25T06:32:44.8607360Z [1m[92m   Compiling[0m libloading v0.8.6
2026-07-25T06:32:45.0051300Z [1m[92m   Compiling[0m tracing-core v0.1.33
2026-07-25T06:32:45.0382800Z [1m[92m   Compiling[0m vec_map v0.8.2
2026-07-25T06:32:45.1907070Z [1m[92m   Compiling[0m bindgen v0.59.2
2026-07-25T06:32:45.4779490Z [1m[92m   Compiling[0m rustls-pki-types v1.11.0
2026-07-25T06:32:46.3294380Z [1m[92m   Compiling[0m ansi_term v0.12.1
2026-07-25T06:32:46.5272690Z [1m[92m   Compiling[0m icu_normalizer_data v1.5.1
2026-07-25T06:32:46.5641300Z [1m[92m   Compiling[0m powerfmt v0.2.0
2026-07-25T06:32:46.7342080Z [1m[92m   Compiling[0m home v0.5.11
2026-07-25T06:32:46.8338830Z [1m[92m   Compiling[0m getrandom v0.3.2
2026-07-25T06:32:46.8637520Z [1m[92m   Compiling[0m strsim v0.8.0
2026-07-25T06:32:47.0825240Z [1m[92m   Compiling[0m httparse v1.10.1
2026-07-25T06:32:47.1536550Z [1m[92m   Compiling[0m either v1.15.0
2026-07-25T06:32:47.4139700Z [1m[92m   Compiling[0m termcolor v1.4.1
2026-07-25T06:32:48.0820440Z [1m[92m   Compiling[0m bitflags v1.3.2
2026-07-25T06:32:48.1844720Z [1m[92m   Compiling[0m utf8parse v0.2.2
2026-07-25T06:32:48.2720600Z [1m[92m   Compiling[0m syn v1.0.109
2026-07-25T06:32:48.3041410Z [1m[92m   Compiling[0m humantime v2.2.0
2026-07-25T06:32:48.5436650Z [1m[92m   Compiling[0m env_logger v0.9.3
2026-07-25T06:32:48.6093850Z [1m[92m   Compiling[0m anstyle-parse v0.2.6
2026-07-25T06:32:48.8238780Z [1m[92m   Compiling[0m clap v2.34.0
2026-07-25T06:32:49.1251860Z [1m[92m   Compiling[0m which v4.4.2
2026-07-25T06:32:49.3859680Z [1m[92m   Compiling[0m deranged v0.4.0
2026-07-25T06:32:50.4566650Z [1m[92m   Compiling[0m tracing v0.1.41
2026-07-25T06:32:52.5459450Z [1m[92m   Compiling[0m ppv-lite86 v0.2.21
2026-07-25T06:32:52.8522630Z [1m[92m   Compiling[0m icu_locid_transform v1.5.0
2026-07-25T06:32:56.6537750Z [1m[92m   Compiling[0m cexpr v0.6.0
2026-07-25T06:32:57.1413760Z [1m[92m   Compiling[0m http-body v1.0.1
2026-07-25T06:32:57.2842470Z [1m[92m   Compiling[0m tokio-util v0.7.14
2026-07-25T06:32:57.5115700Z [1m[92m   Compiling[0m icu_collections v1.5.0
2026-07-25T06:32:58.4145450Z [1m[92m   Compiling[0m block-buffer v0.10.4
2026-07-25T06:32:58.5577150Z [1m[92m   Compiling[0m rustc-hash v1.1.0
2026-07-25T06:32:58.6425260Z [1m[92m   Compiling[0m try-lock v0.2.5
2026-07-25T06:32:58.7396970Z [1m[92m   Compiling[0m num-conv v0.1.0
2026-07-25T06:32:58.8845130Z [1m[92m   Compiling[0m untrusted v0.9.0
2026-07-25T06:32:58.9990050Z [1m[92m   Compiling[0m lazy_static v1.5.0
2026-07-25T06:32:59.0566010Z [1m[92m   Compiling[0m colorchoice v1.0.3
2026-07-25T06:32:59.0715850Z [1m[92m   Compiling[0m is_terminal_polyfill v1.70.1
2026-07-25T06:32:59.1459790Z [1m[92m   Compiling[0m lazycell v1.3.0
2026-07-25T06:32:59.1531060Z [1m[92m   Compiling[0m anstyle-query v1.1.2
2026-07-25T06:32:59.2377830Z [1m[92m   Compiling[0m atomic-waker v1.1.2
2026-07-25T06:32:59.2461180Z [1m[92m   Compiling[0m time-core v0.1.4
2026-07-25T06:32:59.3461900Z [1m[92m   Compiling[0m anstyle v1.0.10
2026-07-25T06:32:59.3548220Z [1m[92m   Compiling[0m peeking_take_while v0.1.2
2026-07-25T06:32:59.6667690Z [1m[92m   Compiling[0m anstream v0.6.18
2026-07-25T06:33:00.3409400Z [1m[92m   Compiling[0m time v0.3.41
2026-07-25T06:33:05.3371420Z [1m[92m   Compiling[0m h2 v0.4.8
2026-07-25T06:33:15.8404500Z [1m[92m   Compiling[0m want v0.3.1
2026-07-25T06:33:16.0029250Z [1m[92m   Compiling[0m digest v0.10.7
2026-07-25T06:33:16.0670530Z [1m[92m   Compiling[0m icu_properties v1.5.1
2026-07-25T06:33:21.3307160Z [1m[92m   Compiling[0m core-foundation v0.9.4
2026-07-25T06:33:22.0689220Z [1m[92m   Compiling[0m security-framework-sys v2.14.0
2026-07-25T06:33:22.2478270Z [1m[92m   Compiling[0m zstd-sys v2.0.15+zstd.1.5.7
2026-07-25T06:33:22.6205790Z [1m[92m   Compiling[0m openssl-src v300.6.0+3.6.2
2026-07-25T06:33:22.9178630Z [1m[92m   Compiling[0m autotools v0.2.7
2026-07-25T06:33:23.1713160Z [1m[92m   Compiling[0m rustix v1.0.5
2026-07-25T06:33:23.5249070Z [1m[92m   Compiling[0m utf8_iter v1.0.4
2026-07-25T06:33:23.6785030Z [1m[92m   Compiling[0m utf16_iter v1.0.5
2026-07-25T06:33:23.8041420Z [1m[92m   Compiling[0m write16 v1.0.0
2026-07-25T06:33:24.2035970Z [1m[92m   Compiling[0m native-tls v0.2.14
2026-07-25T06:33:24.4248830Z [1m[92m   Compiling[0m vcpkg v0.2.15
2026-07-25T06:33:25.1620860Z [1m[92m   Compiling[0m rustls v0.23.26
2026-07-25T06:33:25.3572480Z [1m[92m   Compiling[0m tower-service v0.3.3
2026-07-25T06:33:25.4284960Z [1m[92m   Compiling[0m base64 v0.22.1
2026-07-25T06:33:26.1419430Z [1m[92m   Compiling[0m openssl-sys v0.9.107
2026-07-25T06:33:26.1818380Z [1m[92m   Compiling[0m swift-bridge-ir v0.1.56 (https://github.com/naturecodevoid/swift-bridge#cc1e577d)
2026-07-25T06:33:26.7193560Z [1m[92m   Compiling[0m icu_normalizer v1.5.0
2026-07-25T06:33:30.2351280Z [1m[92m   Compiling[0m security-framework v2.11.1
2026-07-25T06:33:32.7231390Z [1m[92m   Compiling[0m hyper v1.6.0
2026-07-25T06:33:37.8457050Z [1m[92m   Compiling[0m rustls-webpki v0.103.1
2026-07-25T06:33:42.1450290Z [1m[92m   Compiling[0m quick-xml v0.32.0
2026-07-25T06:33:56.6662870Z [1m[92m   Compiling[0m cpufeatures v0.2.17
2026-07-25T06:33:56.7851790Z [1m[92m   Compiling[0m clap_lex v0.7.4
2026-07-25T06:33:58.4132010Z [1m[92m   Compiling[0m thiserror v2.0.12
2026-07-25T06:33:58.7319100Z [1m[92m   Compiling[0m heck v0.5.0
2026-07-25T06:33:58.9437330Z [1m[92m   Compiling[0m strsim v0.11.1
2026-07-25T06:34:00.3300890Z [1m[92m   Compiling[0m percent-encoding v2.3.1
2026-07-25T06:34:00.5955080Z [1m[92m   Compiling[0m form_urlencoded v1.2.1
2026-07-25T06:34:00.8809260Z [1m[92m   Compiling[0m clap_builder v4.5.36
2026-07-25T06:34:17.4471060Z [1m[92m   Compiling[0m clap_derive v4.5.32
2026-07-25T06:34:20.0376620Z [1m[92m   Compiling[0m plist v1.7.1
2026-07-25T06:34:23.2274830Z [1m[92m   Compiling[0m hyper-util v0.1.11
2026-07-25T06:34:27.7385040Z [1m[92m   Compiling[0m idna_adapter v1.2.0
2026-07-25T06:34:57.4332230Z [1m[92m   Compiling[0m rand_core v0.6.4
2026-07-25T06:34:57.7369850Z [1m[92m   Compiling[0m thiserror-impl v2.0.12
2026-07-25T06:34:59.6433410Z [1m[92m   Compiling[0m num-traits v0.2.19
2026-07-25T06:34:59.9249880Z [1m[92m   Compiling[0m lzma-sys v0.1.20
2026-07-25T06:35:00.4027260Z [1m[92m   Compiling[0m bzip2-sys v0.1.13+1.0.8
2026-07-25T06:35:00.6636270Z [1m[92m   Compiling[0m fastrand v2.3.0
2026-07-25T06:35:01.1721060Z [1m[92m   Compiling[0m zstd-safe v7.2.4
2026-07-25T06:35:01.4531320Z [1m[92m   Compiling[0m ryu v1.0.20
2026-07-25T06:35:01.8497600Z [1m[92m   Compiling[0m serde_json v1.0.140
2026-07-25T06:35:02.1297960Z [1m[92m   Compiling[0m tempfile v3.19.1
2026-07-25T06:35:19.9407900Z [1m[92m   Compiling[0m rand_chacha v0.3.1
2026-07-25T06:35:23.1984700Z [1m[92m   Compiling[0m idna v1.0.3
2026-07-25T06:35:26.4947590Z [1m[92m   Compiling[0m tokio-rustls v0.26.2
2026-07-25T06:35:26.8163290Z [1m[92m   Compiling[0m tokio-native-tls v0.3.1
2026-07-25T06:35:26.9786040Z [1m[92m   Compiling[0m clap v4.5.36
2026-07-25T06:35:28.6819570Z [1m[92m   Compiling[0m plist_plus v0.2.6 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/plist_plus)
2026-07-25T06:35:29.0836470Z [1m[92m   Compiling[0m rand_core v0.9.3
2026-07-25T06:35:29.3531570Z [1m[92m   Compiling[0m http-body-util v0.1.3
2026-07-25T06:35:29.6758270Z [1m[92m   Compiling[0m webpki-roots v0.26.8
2026-07-25T06:35:29.8038030Z [1m[92m   Compiling[0m inout v0.1.4
2026-07-25T06:35:29.9334120Z [1m[92m   Compiling[0m sync_wrapper v1.0.2
2026-07-25T06:35:30.0280580Z [1m[92m   Compiling[0m crc32fast v1.4.2
2026-07-25T06:35:30.2889120Z [1m[92m   Compiling[0m openssl v0.10.72
2026-07-25T06:35:30.5402330Z [1m[92m   Compiling[0m adler2 v2.0.0
2026-07-25T06:35:30.6925270Z [1m[92m   Compiling[0m crc-catalog v2.4.0
2026-07-25T06:35:30.7782740Z [1m[92m   Compiling[0m tower-layer v0.3.3
2026-07-25T06:35:31.0364450Z [1m[92m   Compiling[0m byteorder v1.5.0
2026-07-25T06:35:31.3703860Z [1m[92m   Compiling[0m foreign-types-shared v0.1.1
2026-07-25T06:35:31.4370930Z [1m[92m   Compiling[0m foreign-types v0.3.2
2026-07-25T06:35:31.4932750Z [1m[92m   Compiling[0m tower v0.5.2
2026-07-25T06:35:32.0585880Z [1m[92m   Compiling[0m crc v3.2.1
2026-07-25T06:35:33.2810130Z [1m[92m   Compiling[0m miniz_oxide v0.8.8
2026-07-25T06:35:35.3449670Z [1m[92m   Compiling[0m cipher v0.4.4
2026-07-25T06:35:35.6143670Z [1m[92m   Compiling[0m hyper-rustls v0.27.5
2026-07-25T06:35:36.2743190Z [1m[92m   Compiling[0m hyper-tls v0.6.0
2026-07-25T06:35:36.5376330Z [1m[92m   Compiling[0m rand_chacha v0.9.0
2026-07-25T06:35:48.5314530Z [1m[91merror[0m: failed to run custom build command for `plist_plus v0.2.6 (/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/plist_plus)`
2026-07-25T06:35:48.5316590Z 
2026-07-25T06:35:48.5316760Z Caused by:
2026-07-25T06:35:48.5318850Z   process didn't exit successfully: `/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/release/build/plist_plus-241040c3fb6e2ada/build-script-build` (exit status: 101)
2026-07-25T06:35:48.5320830Z   --- stdout
2026-07-25T06:35:48.5321210Z   cargo:rerun-if-changed=wrapper.h
2026-07-25T06:35:48.5321710Z   cargo:rerun-if-changed=build.rs
2026-07-25T06:35:48.5347130Z   running: cd "/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/build" && AR="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar" CC="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" CFLAGS="-O3 -fPIC --target=arm64-apple-ios -miphoneos-version-min=18.0 -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0  -std=gnu17" CPP="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -E --target=arm64-apple-ios -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0" CXX="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++" CXXCPP="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ -E --target=arm64-apple-ios -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0" CXXFLAGS="-O3 -fPIC --target=arm64-apple-ios -miphoneos-version-min=18.0 -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk -miphoneos-version-min=18.0" LC_ALL="C" RANLIB="/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" ac_cv_c_undeclared_builtin_options="-fno-builtin" "sh" "-c" "exec \"$0\" \"$@\"" "/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/libplist/configure" "--prefix=/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out" "--disable-shared" "--enable-static" "--without-cython" "--host=aarch64-apple-darwin"
2026-07-25T06:35:48.5367690Z 
2026-07-25T06:35:48.5367850Z   --- stderr
2026-07-25T06:35:48.5368530Z   configure: WARNING: unrecognized options: --disable-shared, --enable-static
2026-07-25T06:35:48.5371010Z   /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/libplist/configure: line 2650: syntax error near unexpected token `dist-bzip2'
2026-07-25T06:35:48.5374960Z   /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/ThirdParty/SideStore/minimuxer/target/aarch64-apple-ios/release/build/plist_plus-c67777677d4ea9ce/out/libplist/configure: line 2650: `AM_INIT_AUTOMAKE(dist-bzip2 no-dist-gzip check-news)'
2026-07-25T06:35:48.5377070Z 
2026-07-25T06:35:48.5377940Z   thread 'main' (583116) panicked at /Users/runner/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/autotools-0.2.7/src/lib.rs:790:5:
2026-07-25T06:35:48.5379080Z 
2026-07-25T06:35:48.5379380Z   command did not execute successfully, got: exit status: 2
2026-07-25T06:35:48.5379880Z 
2026-07-25T06:35:48.5380060Z   build script failed, must exit now
2026-07-25T06:35:48.5380830Z   note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
2026-07-25T06:35:48.5382070Z [1m[33mwarning[0m: build failed, waiting for other jobs to finish...
2026-07-25T06:37:29.7744580Z make: *** [xcgen] Error 101
2026-07-25T06:37:29.7769040Z ##[error]Process completed with exit code 2.
2026-07-25T06:37:29.7934940Z ##[group]Run set -euo pipefail
2026-07-25T06:37:29.7935770Z [36;1mset -euo pipefail[0m
2026-07-25T06:37:29.7936330Z [36;1mmkdir -p build-diagnostics[0m
2026-07-25T06:37:29.7936810Z [36;1m{[0m
2026-07-25T06:37:29.7937190Z [36;1m  echo '# AlleyCat unsigned IPA failure'[0m
2026-07-25T06:37:29.7937720Z [36;1m  echo[0m
2026-07-25T06:37:29.7938080Z [36;1m  echo "- Run: $GITHUB_RUN_ID"[0m
2026-07-25T06:37:29.7938600Z [36;1m  echo "- Commit: $GITHUB_SHA"[0m
2026-07-25T06:37:29.7939140Z [36;1m  echo '- Workflow: ios-unsigned-ipa.yml'[0m
2026-07-25T06:37:29.7939710Z [36;1m  echo "- Rust cache hit: true"[0m
2026-07-25T06:37:29.7940250Z [36;1m  for log in runtime-build xcodebuild; do[0m
2026-07-25T06:37:29.7940780Z [36;1m    echo[0m
2026-07-25T06:37:29.7941130Z [36;1m    echo "## $log tail"[0m
2026-07-25T06:37:29.7941560Z [36;1m    echo '```text'[0m
2026-07-25T06:37:29.7942100Z [36;1m    tail -n 500 "build/logs/$log.log" 2>/dev/null || true[0m
2026-07-25T06:37:29.7942750Z [36;1m    echo '```'[0m
2026-07-25T06:37:29.7943120Z [36;1m  done[0m
2026-07-25T06:37:29.7943570Z [36;1m} > build-diagnostics/alleycat-ios-last-error.md[0m
2026-07-25T06:37:29.7944230Z [36;1mgit config user.name github-actions[bot][0m
2026-07-25T06:37:29.7945060Z [36;1mgit config user.email 41898282+github-actions[bot]@users.noreply.github.com[0m
2026-07-25T06:37:29.7946010Z [36;1mgit add build-diagnostics/alleycat-ios-last-error.md[0m
2026-07-25T06:37:29.7947380Z [36;1mgit commit -m 'Record AlleyCat IPA failure [skip ci]' || exit 0[0m
2026-07-25T06:37:29.7948120Z [36;1mgit pull --rebase origin main[0m
2026-07-25T06:37:29.7948610Z [36;1mgit push origin HEAD:main[0m
2026-07-25T06:37:29.8267430Z shell: /bin/bash -e {0}
2026-07-25T06:37:29.8267840Z env:
2026-07-25T06:37:29.8268200Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T06:37:29.8268720Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T06:37:29.8269150Z   CARGO_INCREMENTAL: 0
2026-07-25T06:37:29.8269520Z   CARGO_BUILD_JOBS: 2
2026-07-25T06:37:29.8269920Z   CARGO_NET_RETRY: 10
2026-07-25T06:37:29.8270290Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T06:37:29.8270710Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T06:37:29.8271170Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T06:37:29.8271610Z   IOS_MIN: 16.1
2026-07-25T06:37:29.8271940Z   RUSTC_WRAPPER: 
2026-07-25T06:37:29.8272280Z   SCCACHE_DISABLE: 1
2026-07-25T06:37:29.8272660Z   SOURCE_ROOT: upstream/litter
2026-07-25T06:37:29.8273410Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T06:37:29.8274240Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T06:37:29.8274830Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T06:37:29.8275520Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T06:37:29.8276000Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T06:37:29.8276480Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T06:37:29.8277010Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T06:37:29.8277510Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T06:37:29.8278020Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T06:37:29.8278580Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T06:37:29.8279020Z   CARGO_TERM_COLOR: always
2026-07-25T06:37:29.8279680Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T06:37:29.8280720Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T06:37:29.8281480Z ##[endgroup]
2026-07-25T06:37:30.1700450Z [main a450b51] Record AlleyCat IPA failure [skip ci]
2026-07-25T06:37:30.1701700Z  1 file changed, 2 insertions(+), 2 deletions(-)
2026-07-25T06:37:31.1480090Z From https://github.com/NightVibes33/Codex-DEB-Test
2026-07-25T06:37:31.1480840Z  * branch            main       -> FETCH_HEAD
2026-07-25T06:37:31.1481520Z    417d350..b4e26d8  main       -> origin/main
2026-07-25T06:37:31.3203040Z Rebasing (1/1)
2026-07-25T06:37:31.3203650Z Successfully rebased and updated refs/heads/main.
2026-07-25T06:37:32.4722060Z To https://github.com/NightVibes33/Codex-DEB-Test
2026-07-25T06:37:32.4722830Z    b4e26d8..9a04e9c  HEAD -> main
2026-07-25T06:37:32.4930570Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T06:37:32.4933430Z ##[group]Run actions/upload-artifact@v4
2026-07-25T06:37:32.4933990Z with:
2026-07-25T06:37:32.4934410Z   name: AlleyCat-IPA-Build-Logs-30147271339
2026-07-25T06:37:32.4934990Z   path: build/logs/
build-diagnostics/

2026-07-25T06:37:32.4935560Z   if-no-files-found: warn
2026-07-25T06:37:32.4936030Z   compression-level: 6
2026-07-25T06:37:32.4936460Z   overwrite: false
2026-07-25T06:37:32.4936890Z   include-hidden-files: false
2026-07-25T06:37:32.4937370Z env:
2026-07-25T06:37:32.4937770Z   FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
2026-07-25T06:37:32.4938350Z   HOMEBREW_NO_AUTO_UPDATE: 1
2026-07-25T06:37:32.4938860Z   CARGO_INCREMENTAL: 0
2026-07-25T06:37:32.4939400Z   CARGO_BUILD_JOBS: 2
2026-07-25T06:37:32.4939810Z   CARGO_NET_RETRY: 10
2026-07-25T06:37:32.4940260Z   CARGO_HTTP_TIMEOUT: 120
2026-07-25T06:37:32.4940750Z   CARGO_HTTP_MULTIPLEXING: false
2026-07-25T06:37:32.4941310Z   IOS_RUST_PROFILE: mobile-release
2026-07-25T06:37:32.4941790Z   IOS_MIN: 16.1
2026-07-25T06:37:32.4942620Z   RUSTC_WRAPPER: 
2026-07-25T06:37:32.4943070Z   SCCACHE_DISABLE: 1
2026-07-25T06:37:32.4943510Z   SOURCE_ROOT: upstream/litter
2026-07-25T06:37:32.4944330Z   DERIVED_DATA_PATH: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/build/DerivedData
2026-07-25T06:37:32.4945220Z   RUSTY_V8_VERSION: 149.2.0
2026-07-25T06:37:32.4945910Z   RUSTY_V8_ARCHIVE_NAME: librusty_v8_release_x86_64-apple-darwin.a.gz
2026-07-25T06:37:32.4946670Z   LITTER_IOS_BUILD_MODE: full-sideload
2026-07-25T06:37:32.4947210Z   LITTER_NYXIAN_PRIVATE_BUILD: 1
2026-07-25T06:37:32.4947820Z   LITTER_EMBED_PRIVATE_BUILDKIT_ASSETS: 0
2026-07-25T06:37:32.4948430Z   LITTER_PRESERVE_NYXIAN_LIVEPROCESS: 1
2026-07-25T06:37:32.4949010Z   LITTER_SKIP_ALLEYCAT_UPDATE: 1
2026-07-25T06:37:32.4949610Z   MD_APPLE_SDK_ROOT: /Applications/Xcode_26.3.app
2026-07-25T06:37:32.4950230Z   CARGO_HOME: /Users/runner/.cargo
2026-07-25T06:37:32.4950750Z   CARGO_TERM_COLOR: always
2026-07-25T06:37:32.4951490Z   ZIG_GLOBAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T06:37:32.4952570Z   ZIG_LOCAL_CACHE_DIR: /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/.zig-cache
2026-07-25T06:37:32.4953400Z ##[endgroup]
2026-07-25T06:37:32.7606710Z (node:86284) [DEP0040] DeprecationWarning: The `punycode` module is deprecated. Please use a userland alternative instead.
2026-07-25T06:37:32.7608240Z (Use `node --trace-deprecation ...` to show where the warning was created)
2026-07-25T06:37:32.7690940Z Multiple search paths detected. Calculating the least common ancestor of all paths
2026-07-25T06:37:32.7694330Z The least common ancestor is /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test. This will be the root directory of the artifact
2026-07-25T06:37:32.7695670Z With the provided path, there will be 6 files uploaded
2026-07-25T06:37:32.7699520Z Artifact name is valid!
2026-07-25T06:37:32.7700070Z Root directory input is valid!
2026-07-25T06:37:33.1050340Z Beginning upload of artifact content to blob storage
2026-07-25T06:37:33.1396270Z (node:86284) [DEP0169] DeprecationWarning: `url.parse()` behavior is not standardized and prone to errors that have security implications. Use the WHATWG URL API instead. CVEs are not issued for `url.parse()` vulnerabilities.
2026-07-25T06:37:33.4338930Z Uploaded bytes 9201
2026-07-25T06:37:33.5161960Z Finished uploading artifact content to blob storage!
2026-07-25T06:37:33.5163140Z SHA256 digest of uploaded artifact zip is 58b66b9fc90057c630e5cd441b40dc7fb6b09c81db0b77f2003524311bee6b5b
2026-07-25T06:37:33.5164230Z Finalizing artifact upload
2026-07-25T06:37:33.7423310Z Artifact AlleyCat-IPA-Build-Logs-30147271339.zip successfully finalized. Artifact ID 8616601043
2026-07-25T06:37:33.7425870Z Artifact AlleyCat-IPA-Build-Logs-30147271339 has been successfully uploaded! Final size is 9201 bytes. Artifact ID is 8616601043
2026-07-25T06:37:33.7436340Z Artifact download URL: https://github.com/NightVibes33/Codex-DEB-Test/actions/runs/30147271339/artifacts/8616601043
2026-07-25T06:37:33.7746140Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T06:37:33.7748980Z Post job cleanup.
2026-07-25T06:37:34.4785850Z Zig cache directory is inaccessible; nothing to save
2026-07-25T06:37:34.5080200Z Node 20 is being deprecated. This workflow is running with Node 24 by default. If you need to temporarily use Node 20, you can set the ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
2026-07-25T06:37:34.5083010Z Post job cleanup.
2026-07-25T06:37:34.6717850Z [command]/usr/local/bin/git version
2026-07-25T06:37:34.6818470Z git version 2.55.0
2026-07-25T06:37:34.6853780Z Copying '/Users/runner/.gitconfig' to '/Users/runner/work/_temp/81e0d697-b0d6-4d9b-95b7-104d34ea6b0e/.gitconfig'
2026-07-25T06:37:34.6873300Z Temporarily overriding HOME='/Users/runner/work/_temp/81e0d697-b0d6-4d9b-95b7-104d34ea6b0e' before making global git config changes
2026-07-25T06:37:34.6874940Z Adding repository directory to the temporary git global config as a safe directory
2026-07-25T06:37:34.6880300Z [command]/usr/local/bin/git config --global --add safe.directory /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test
2026-07-25T06:37:34.6991700Z [command]/usr/local/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-07-25T06:37:34.7095660Z [command]/usr/local/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-07-25T06:37:34.8983540Z [command]/usr/local/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-07-25T06:37:34.9071230Z http.https://github.com/.extraheader
2026-07-25T06:37:34.9084300Z [command]/usr/local/bin/git config --local --unset-all http.https://github.com/.extraheader
2026-07-25T06:37:34.9191290Z [command]/usr/local/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-07-25T06:37:35.0570480Z [command]/usr/local/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-07-25T06:37:35.0681060Z [command]/usr/local/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-07-25T06:37:35.2265680Z Cleaning up orphan processes
2026-07-25T06:37:35.6317760Z ##[warning]Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on Node.js 24: actions/cache/restore@v4, actions/cache@v4, actions/checkout@v4, actions/upload-artifact@v4, mlugg/setup-zig@v2. For more information see: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
```
