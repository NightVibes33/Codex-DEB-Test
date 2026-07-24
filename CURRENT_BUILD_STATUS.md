# Current IPA and DEB build status

- Run: 30110907230
- Commit: 651116ae81b8a543b0dfe3ede90e3b4bf328ae34
- Target: iOS 16.1+ (iPadOS 16.7.11 supported)
- rusty_v8 cache restored: 
- Rust cache restored: 
- Rust cache valid: false
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Alley Cat runtime: failure
- iOS application: skipped
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## runtime-build tail
```text
      |     |  +- metal Ghostty (Ghostty.ir) (reused)
      |     +- metallib Ghostty (Ghostty.metallib) (+2 more reused dependencies)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1 (+55 more reused dependencies)

error: the following build command failed with exit code 1:
/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/93d574a034ab656b2976514b60edc2e5/build /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/lib /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local /Users/runner/.cache/darksword-zig-global --seed 0x4bb49e05 -Zf945f70fc821844a -Dlitter-ios-static=true -Dapp-runtime=none -Drenderer=metal -Dfont-backend=coretext -Demit-exe=false -Demit-lib-vt=false -Demit-xcframework=false -Demit-macos-app=false -Demit-docs=false -Demit-terminfo=false -Demit-termcap=false -Demit-themes=false -Demit-webdata=false -Di18n=false -Dsentry=false -Dtarget=aarch64-ios.16.1 -Doptimize=ReleaseFast --prefix /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/ios-device
warning: Ghostty Zig build attempt 2 failed; retrying in 30s with preserved package cache...
install
+- install generated to ghostty-internal.a
   +- libtool ghostty-internal (libghostty-internal-fat.a)
      +- ranlib ghostty-internal #11 (11-libghostty-internal-fat.a)
         +- compile lib ghostty ReleaseFast aarch64-ios.16.1
            +- metallib Ghostty (Ghostty.metallib)
               +- metal Ghostty (Ghostty.ir) failure
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain
error: stderr:
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain

error: the following command exited with error code 1:
/usr/bin/xcrun -sdk iphoneos metal -o /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/26d5ae27b4985da82347d43d73bf101f/Ghostty.ir -c /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty/src/renderer/shaders/shaders.metal -mios-version-min=16.1.0

Build Summary: 63/70 steps succeeded; 1 failed
install transitive failure
+- install generated to ghostty-internal.a transitive failure
   +- libtool ghostty-internal (libghostty-internal-fat.a) transitive failure
      +- ranlib ghostty-internal #11 (11-libghostty-internal-fat.a) transitive failure
      |  +- compile lib ghostty ReleaseFast aarch64-ios.16.1 transitive failure
      |     +- metallib Ghostty (Ghostty.metallib) transitive failure
      |     |  +- metal Ghostty (Ghostty.ir) failure
      |     |  +- metal Ghostty (Ghostty.ir) (reused)
      |     +- metallib Ghostty (Ghostty.metallib) (+2 more reused dependencies)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1 (+55 more reused dependencies)

error: the following build command failed with exit code 1:
/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/93d574a034ab656b2976514b60edc2e5/build /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/lib /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local /Users/runner/.cache/darksword-zig-global --seed 0xbe75d93f -Z94184000c748b153 -Dlitter-ios-static=true -Dapp-runtime=none -Drenderer=metal -Dfont-backend=coretext -Demit-exe=false -Demit-lib-vt=false -Demit-xcframework=false -Demit-macos-app=false -Demit-docs=false -Demit-terminfo=false -Demit-termcap=false -Demit-themes=false -Demit-webdata=false -Di18n=false -Dsentry=false -Dtarget=aarch64-ios.16.1 -Doptimize=ReleaseFast --prefix /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/ios-device
warning: Ghostty Zig build attempt 3 failed; retrying in 45s with preserved package cache...
install
+- install generated to ghostty-internal.a
   +- libtool ghostty-internal (libghostty-internal-fat.a)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1
         +- metallib Ghostty (Ghostty.metallib)
            +- metal Ghostty (Ghostty.ir) failure
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain
error: stderr:
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain

error: the following command exited with error code 1:
/usr/bin/xcrun -sdk iphoneos metal -o /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/26d5ae27b4985da82347d43d73bf101f/Ghostty.ir -c /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty/src/renderer/shaders/shaders.metal -mios-version-min=16.1.0

Build Summary: 63/70 steps succeeded; 1 failed
install transitive failure
+- install generated to ghostty-internal.a transitive failure
   +- libtool ghostty-internal (libghostty-internal-fat.a) transitive failure
      +- ranlib ghostty-internal #11 (11-libghostty-internal-fat.a) transitive failure
      |  +- compile lib ghostty ReleaseFast aarch64-ios.16.1 transitive failure
      |     +- metallib Ghostty (Ghostty.metallib) transitive failure
      |     |  +- metal Ghostty (Ghostty.ir) failure
      |     |  +- metal Ghostty (Ghostty.ir) (reused)
      |     +- metallib Ghostty (Ghostty.metallib) (+2 more reused dependencies)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1 (+55 more reused dependencies)

error: the following build command failed with exit code 1:
/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/93d574a034ab656b2976514b60edc2e5/build /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/lib /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local /Users/runner/.cache/darksword-zig-global --seed 0x4084dac3 -Z04e75d28c2755a11 -Dlitter-ios-static=true -Dapp-runtime=none -Drenderer=metal -Dfont-backend=coretext -Demit-exe=false -Demit-lib-vt=false -Demit-xcframework=false -Demit-macos-app=false -Demit-docs=false -Demit-terminfo=false -Demit-termcap=false -Demit-themes=false -Demit-webdata=false -Di18n=false -Dsentry=false -Dtarget=aarch64-ios.16.1 -Doptimize=ReleaseFast --prefix /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/ios-device
warning: Ghostty Zig build attempt 4 failed; retrying in 60s with preserved package cache...
install
+- install generated to ghostty-internal.a
   +- libtool ghostty-internal (libghostty-internal-fat.a)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1
         +- metallib Ghostty (Ghostty.metallib)
            +- metal Ghostty (Ghostty.ir) failure
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain
error: stderr:
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain

error: the following command exited with error code 1:
/usr/bin/xcrun -sdk iphoneos metal -o /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/26d5ae27b4985da82347d43d73bf101f/Ghostty.ir -c /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty/src/renderer/shaders/shaders.metal -mios-version-min=16.1.0

Build Summary: 63/70 steps succeeded; 1 failed
install transitive failure
+- install generated to ghostty-internal.a transitive failure
   +- libtool ghostty-internal (libghostty-internal-fat.a) transitive failure
      +- ranlib ghostty-internal #11 (11-libghostty-internal-fat.a) transitive failure
      |  +- compile lib ghostty ReleaseFast aarch64-ios.16.1 transitive failure
      |     +- metallib Ghostty (Ghostty.metallib) transitive failure
      |     |  +- metal Ghostty (Ghostty.ir) failure
      |     |  +- metal Ghostty (Ghostty.ir) (reused)
      |     +- metallib Ghostty (Ghostty.metallib) (+2 more reused dependencies)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1 (+55 more reused dependencies)

error: the following build command failed with exit code 1:
/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/93d574a034ab656b2976514b60edc2e5/build /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/lib /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local /Users/runner/.cache/darksword-zig-global --seed 0xd69cc41d -Z95c3edde0a4bb53a -Dlitter-ios-static=true -Dapp-runtime=none -Drenderer=metal -Dfont-backend=coretext -Demit-exe=false -Demit-lib-vt=false -Demit-xcframework=false -Demit-macos-app=false -Demit-docs=false -Demit-terminfo=false -Demit-termcap=false -Demit-themes=false -Demit-webdata=false -Di18n=false -Dsentry=false -Dtarget=aarch64-ios.16.1 -Doptimize=ReleaseFast --prefix /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/ios-device
warning: Ghostty Zig build attempt 5 failed; retrying in 75s with preserved package cache...
install
+- install generated to ghostty-internal.a
   +- libtool ghostty-internal (libghostty-internal-fat.a)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1
         +- metallib Ghostty (Ghostty.metallib)
            +- metal Ghostty (Ghostty.ir) failure
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain
error: stderr:
error: error: cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain

error: the following command exited with error code 1:
/usr/bin/xcrun -sdk iphoneos metal -o /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/26d5ae27b4985da82347d43d73bf101f/Ghostty.ir -c /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty/src/renderer/shaders/shaders.metal -mios-version-min=16.1.0

Build Summary: 63/70 steps succeeded; 1 failed
install transitive failure
+- install generated to ghostty-internal.a transitive failure
   +- libtool ghostty-internal (libghostty-internal-fat.a) transitive failure
      +- ranlib ghostty-internal #11 (11-libghostty-internal-fat.a) transitive failure
      |  +- compile lib ghostty ReleaseFast aarch64-ios.16.1 transitive failure
      |     +- metallib Ghostty (Ghostty.metallib) transitive failure
      |     |  +- metal Ghostty (Ghostty.ir) failure
      |     |  +- metal Ghostty (Ghostty.ir) (reused)
      |     +- metallib Ghostty (Ghostty.metallib) (+2 more reused dependencies)
      +- compile lib ghostty ReleaseFast aarch64-ios.16.1 (+55 more reused dependencies)

error: the following build command failed with exit code 1:
/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local/o/93d574a034ab656b2976514b60edc2e5/build /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/lib /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/zig-cache/local /Users/runner/.cache/darksword-zig-global --seed 0x96f506b3 -Zc7b29b4e2a164c4b -Dlitter-ios-static=true -Dapp-runtime=none -Drenderer=metal -Dfont-backend=coretext -Demit-exe=false -Demit-lib-vt=false -Demit-xcframework=false -Demit-macos-app=false -Demit-docs=false -Demit-terminfo=false -Demit-termcap=false -Demit-themes=false -Demit-webdata=false -Di18n=false -Dsentry=false -Dtarget=aarch64-ios.16.1 -Doptimize=ReleaseFast --prefix /Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/apps/ios/GeneratedRust/ghostty-build/ios-device
error: Ghostty Zig build failed after 6 attempts
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
