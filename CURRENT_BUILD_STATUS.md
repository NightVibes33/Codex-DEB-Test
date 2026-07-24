# Current IPA and DEB build status

- Run: 30108430068
- Commit: 9fb6701b67265be9d793fda0f98b8204ed8606ea
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
==> Skipping Alleycat main refresh (LITTER_SKIP_ALLEYCAT_UPDATE=1)
==> libghostty artifacts missing; building
==> Installing Zig 0.15.2 from https://ziglang.org/download/0.15.2/zig-x86_64-macos-0.15.2.tar.xz...
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
  0      0   0      0   0      0      0      0                              0  6 53.21M   6  3.57M   0      0  2.76M      0   00:19   00:01   00:18  3.46M 61 53.21M  61 32.82M   0      0 14.30M      0   00:03   00:02   00:01 16.15M100 53.21M 100 53.21M   0      0 18.14M      0   00:02   00:02         16.15M100 53.21M 100 53.21M   0      0 18.14M      0   00:02   00:02         16.15M100 53.21M 100 53.21M   0      0 18.13M      0   00:02   00:02         16.15M
==> Using Zig 0.15.2 from /Users/runner/.cache/darksword-zig/0.15.2-x86_64-macos/zig
==> Preserving current ghostty checkout a968e120d (recorded gitlink 55ee2979d)
==> Applying litter-mobile-embed.patch to submodule...
==> ghostty submodule ready at a968e12
==> Preparing Zig host macOS SDK shim from /Applications/Xcode_26.3.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.2.sdk...
==> Building Ghostty iOS static libraries from a968e12...
==> Building Ghostty ios-device static library...
/Users/runner/work/Codex-DEB-Test/Codex-DEB-Test/upstream/litter/shared/third_party/ghostty/pkg/dcimgui/build.zig.zon:18:20: error: bad HTTP response code: '504 Gateway Timeout'
            .url = "https://github.com/ocornut/imgui/archive/refs/tags/v1.92.5-docking.tar.gz",
                   ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
