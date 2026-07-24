# Current IPA and DEB build status

- Run: 30106599583
- Commit: ab8736cad010e38b86440a3ab9f38d82c3b3ab49
- Target: iOS 16.1+ (iPadOS 16.7.11 supported)
- Rust cache restored: 
- Rust cache valid: false
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Alley Cat runtime: cancelled
- iOS application: skipped
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## runtime-build tail
```text
==> Skipping Alleycat main refresh (LITTER_SKIP_ALLEYCAT_UPDATE=1)
==> libghostty artifacts missing; building
==> Installing Zig 0.15.2 from https://ziglang.org/download/0.15.2/zig-x86_64-macos-0.15.2.tar.xz...
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
  0      0   0      0   0      0      0      0                              0  6 53.21M   6  3.53M   0      0  2.82M      0   00:18   00:01   00:17  3.53M 60 53.21M  60 32.43M   0      0 14.40M      0   00:03   00:02   00:01 16.22M100 53.21M 100 53.21M   0      0 17.56M      0   00:03   00:03         16.22M100 53.21M 100 53.21M   0      0 17.55M      0   00:03   00:03         16.22M100 53.21M 100 53.21M   0      0 17.55M      0   00:03   00:03         16.22M
==> Using Zig 0.15.2 from /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig
==> Preserving current ghostty checkout a968e120d (recorded gitlink 55ee2979d)
==> Applying litter-mobile-embed.patch to submodule...
==> ghostty submodule ready at a968e12
==> Preparing Zig host macOS SDK shim from /Applications/Xcode_26.3.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk...
==> Building Ghostty iOS static libraries from a968e12...
==> Building Ghostty ios-device static library...
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
