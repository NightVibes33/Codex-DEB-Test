# Current IPA and DEB build status

- Run: 30104929579
- Commit: 06a3801604734db03733b8ec4f9cb6e456443f2e
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
==> Resolving shared Rust Alleycat deps to dnakov/alleycat main (3c6dfe2c6b060864d8cb0fcae58f73a6ed1ea10f)...
==> libghostty artifacts missing; building
==> Installing Zig 0.15.2 from https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  2 48.2M    2 1023k    0     0   652k      0  0:01:15  0:00:01  0:01:14  652k 28 48.2M   28 13.5M    0     0  5658k      0  0:00:08  0:00:02  0:00:06 5657k 73 48.2M   73 35.2M    0     0   9.9M      0  0:00:04  0:00:03  0:00:01  9.9M100 48.2M  100 48.2M    0     0  11.6M      0  0:00:04  0:00:04 --:--:-- 11.6M
==> Using Zig 0.15.2 from /Users/runner/.cache/darksword-zig/0.15.2-aarch64-macos/zig
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
