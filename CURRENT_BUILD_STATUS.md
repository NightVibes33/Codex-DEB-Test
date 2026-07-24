# Current IPA and DEB build status

- Run: 30104659488
- Commit: e2ce7c64f19bf3bb07e1cdf3d8febfd4201c74c7
- Source verification: success
- Pinned dependencies: success
- Build tools: success
- Runtime/Xcode project: cancelled
- iOS application: skipped
- Root daemon: skipped
- IPA and DEB package: skipped
- IPA exists: no
- DEB exists: no

## runtime-build tail
```text
==> Resolving shared Rust Alleycat deps to dnakov/alleycat main (3c6dfe2c6b060864d8cb0fcae58f73a6ed1ea10f)...
==> Resolving kittylitter Alleycat dep to dnakov/alleycat main (3c6dfe2c6b060864d8cb0fcae58f73a6ed1ea10f)...
==> Syncing codex submodule...
==> Syncing codex submodule...
==> Vendored source: using pinned current codex checkout b39d8b474
==> codex submodule already at recorded gitlink b39d8b474
==> Applying mobile-bridge-codex-0.144.1.patch to submodule...
==> codex submodule ready at b39d8b4
==> Syncing ghostty submodule + applying Litter patches...
==> Preserving current ghostty checkout a968e120d (recorded gitlink 55ee2979d)
==> Applying litter-mobile-embed.patch to submodule...
==> ghostty submodule ready at a968e12
==> Building Ghostty renderer for iOS...
==> Installing Zig 0.15.2 from https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0 48.2M    0  239k    0     0   238k      0  0:03:27  0:00:01  0:03:26  238k 21 48.2M   21 10.4M    0     0  5580k      0  0:00:08  0:00:01  0:00:07 5578k 67 48.2M   67 32.8M    0     0  11.3M      0  0:00:04  0:00:02  0:00:02 11.3M100 48.2M  100 48.2M    0     0  13.7M      0  0:00:03  0:00:03 --:--:-- 13.7M
==> Using Zig 0.15.2 from /Users/runner/.cache/darksword-zig/0.15.2-aarch64-macos/zig
==> Preserving current ghostty checkout a968e120d (recorded gitlink 55ee2979d)
==> litter-mobile-embed.patch already applied.
==> ghostty submodule ready at a968e12
==> Building Ghostty iOS static libraries from a968e12...
==> Building Ghostty ios-device static library...
```

## xcodebuild tail
```text
```

## rootd-build tail
```text
```
