# Hidden Build / Device Status

- Run: 32674995933
- Commit: 1a50cea5c691f6d8f2a38bbf79458be1a75c6784
- Build step: success
- Device step: failure

## Device proof and scan summary
```text
Warning: Permanently added '100.116.117.65' (ED25519) to the list of known hosts.
checkpoint=dpkg_install
(Reading database ... 25607 files and directories currently installed.)
Preparing to unpack .../Hidden-0.1.0-rootless.deb ...
Unpacking com.nightvibes.hidden (0.1.0) over (0.1.0) ...
Setting up com.nightvibes.hidden (0.1.0) ...
Processing triggers for uikittools (2.1.8) ...
installed_version=0.1.0
hidden_pid=5506
HIDDEN_DEVICE_FAIL=scan_report_timeout
```

## Validation log
```text
build_rc=0
built_deb=packages/com.nightvibes.hidden_0.1.0_iphoneos-arm64.deb
package_name=com.nightvibes.hidden
package_version=0.1.0
package_arch=iphoneos-arm64
package_contents_begin
drwxr-xr-x 0/root            0 2026-08-23 23:55 .
drwxr-xr-x 0/root            0 2026-08-23 23:55 var
drwxr-xr-x 0/root            0 2026-08-23 23:55 var/jb
drwxr-xr-x 0/root            0 2026-08-23 23:55 var/jb/Applications
drwxr-xr-x 0/root            0 2026-08-23 23:55 var/jb/Applications/Hidden.app
-rwxr-xr-x 0/root       107024 2026-08-23 23:55 var/jb/Applications/Hidden.app/Hidden
-rw-r--r-- 0/root         1613 2026-08-23 23:54 var/jb/Applications/Hidden.app/Info.plist
package_contents_end
extracted_files_begin
hidden-deb-root/var/jb/Applications/Hidden.app/Hidden
hidden-deb-root/var/jb/Applications/Hidden.app/Info.plist
extracted_files_end
validated_app_binary=hidden-deb-root/var/jb/Applications/Hidden.app/Hidden
hidden-deb-root/var/jb/Applications/Hidden.app/Hidden: Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|PIE>
signature_ok=/System/Library/PrivateFrameworks
signature_ok=PreferenceManifestsInternal
signature_note=not_present_in_final_binary:Scanning PrivateFrameworks
source_scanner_targets=pass
579304d4fd11cc886b9c2d868101d75e0b1506286eff6f7dbcf68a242ad7a951  Hidden-0.1.0-rootless.deb
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
