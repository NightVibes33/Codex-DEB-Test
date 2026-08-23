# Hidden Build / Device Status

- Run: 32674787155
- Commit: 12c3bcd377630a453b7c06602a6a5c79a9347628
- Build step: success
- Device step: success

## Device proof
```text
Warning: Permanently added '100.116.117.65' (ED25519) to the list of known hosts.
checkpoint=dpkg_install
Selecting previously unselected package com.nightvibes.hidden.
(Reading database ... 25604 files and directories currently installed.)
Preparing to unpack .../Hidden-0.1.0-rootless.deb ...
Unpacking com.nightvibes.hidden (0.1.0) ...
Setting up com.nightvibes.hidden (0.1.0) ...
Processing triggers for uikittools (2.1.8) ...
installed_version=0.1.0
hidden_pid=5429
package_payload=pass
uicache=pass
homescreen_launch=pass
device_proof=success
```

## Validation log
```text
build_rc=0
built_deb=packages/com.nightvibes.hidden_0.1.0_iphoneos-arm64.deb
package_name=com.nightvibes.hidden
package_version=0.1.0
package_arch=iphoneos-arm64
package_contents_begin
drwxr-xr-x 0/root            0 2026-08-23 23:51 .
drwxr-xr-x 0/root            0 2026-08-23 23:51 var
drwxr-xr-x 0/root            0 2026-08-23 23:51 var/jb
drwxr-xr-x 0/root            0 2026-08-23 23:51 var/jb/Applications
drwxr-xr-x 0/root            0 2026-08-23 23:51 var/jb/Applications/Hidden.app
-rwxr-xr-x 0/root        89888 2026-08-23 23:51 var/jb/Applications/Hidden.app/Hidden
-rw-r--r-- 0/root         1613 2026-08-23 23:50 var/jb/Applications/Hidden.app/Info.plist
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
8d638ec7105bd666433f3fbe9d03d4f610017cfd842b8d016014c06142052947  Hidden-0.1.0-rootless.deb
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
