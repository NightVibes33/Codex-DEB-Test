# Hidden Build / Device Status

- Run: 32676035976
- Commit: 983f357b19043269fb6eeaf4429aa8e85db33df2
- Build step: success
- Device step: failure

## Device proof and scan summary
```text
HIDDEN_DEVICE_FAIL=initial_connect
```

## Validation log
```text
build_rc=0
built_deb=packages/com.nightvibes.hidden_0.1.0_iphoneos-arm64.deb
package_name=com.nightvibes.hidden
package_version=0.1.0
package_arch=iphoneos-arm64
package_contents_begin
drwxr-xr-x 0/root            0 2026-08-24 00:15 .
drwxr-xr-x 0/root            0 2026-08-24 00:15 var
drwxr-xr-x 0/root            0 2026-08-24 00:15 var/jb
drwxr-xr-x 0/root            0 2026-08-24 00:15 var/jb/Applications
drwxr-xr-x 0/root            0 2026-08-24 00:15 var/jb/Applications/Hidden.app
-rwxr-xr-x 0/root       107120 2026-08-24 00:15 var/jb/Applications/Hidden.app/Hidden
-rw-r--r-- 0/root         1613 2026-08-24 00:14 var/jb/Applications/Hidden.app/Info.plist
package_contents_end
validated_app_binary=hidden-deb-root/var/jb/Applications/Hidden.app/Hidden
hidden-deb-root/var/jb/Applications/Hidden.app/Hidden: Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|PIE>
source_scanner_targets=pass
8e9e628a5bc7b7d976195c86afc46155564679a0845a2a74a47aa7404b407ccb  Hidden-0.1.0-rootless.deb
package_validation=success
```

## Build log tail
```text
[0;36m==> [1;39mCleaning…[m
[1;31m> [1;3;39mMaking all for application Hidden…[m
[0;35m==> [1;39mCopying resource directories into the application wrapper…[m
[0;32m==> [1;39mCompiling Sources/main.m (arm64)…[m
[0;33m==> [1;39mLinking application Hidden (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for Hidden…[m
[0;34m==> [1;39mStripping Hidden (arm64)…[m
[0;34m==> [1;39mSigning Hidden…[m
[1;31m> [1;3;39mMaking stage for application Hidden…[m
[0;36m==> [1;36mNotice:[m Neither plutil, ply, or libplist-utils are installed, so XML plist files were not optimized.
dm.pl: building package `com.nightvibes.hidden:iphoneos-arm64' in `./packages/com.nightvibes.hidden_0.1.0_iphoneos-arm64.deb'
```
