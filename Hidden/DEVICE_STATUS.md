# Hidden Build / Device Status

- Run: 32675376114
- Commit: c5e91f4454b680469db636fbff7753ce12226a79
- Build step: success
- Device step: success

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
hidden_pid=6271
scan_report_bytes=216180
package_payload=pass
uicache=pass
homescreen_launch=pass
system_scan_report=pass
device_proof=success
scan_total_findings=7913
scan_reported_findings=750
scan_os=Version 16.7.11 (Build 20H360)
scan_category_counts={"Capability Gate":481,"Developer / Diagnostics":559,"Experimental":21,"Feature Flag":1876,"Hidden UI":4976}
scan_top_targets=Settings/AccessibilitySettings, SpringBoard, Settings/DeveloperSettings, MobileSMS, Settings/CameraSettings, Settings/HearingSettings, SpringBoardUIServices (PrivateFramework), Settings/AppClipDeveloperSettings, AppStore, Settings/MobileSlideShowSettings, HomeUIService, Settings/MusicSettings, StoreKitUIService, Settings/InternationalSettings, Preferences
finding_01=score:14 | Settings/CallWaitingTelephonySettings | Developer / Diagnostics | _os_variant_has_internal_diagnostics | /System/Library/PreferenceBundles/CallWaitingTelephonySettings.bundle/CallWaitingTelephonySettings
finding_02=score:14 | Settings/DeveloperSettings | Developer / Diagnostics | items[51].set = setWidgetKitDeveloperModeEnabled:specifier: | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DTSettings.plist
finding_03=score:14 | Settings/DictionarySettings | Developer / Diagnostics | _os_variant_has_internal_diagnostics | /System/Library/PreferenceBundles/DictionarySettings.bundle/DictionarySettings
finding_04=score:13 | Settings/FocusSettings | Feature Flag | _$s12FeatureFlags02isA7EnabledySbAA0aB3Key_pF | /System/Library/PreferenceBundles/FocusSettings.bundle/FocusSettings
finding_05=score:13 | Settings/HomeSettings | Developer / Diagnostics | _HFPreferencesInternalDebuggingEnabledKey | /System/Library/PreferenceBundles/HomeSettings.bundle/HomeSettings
finding_06=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | $s24AppClipDeveloperSettings0C15DiagnosticsViewV4bodyQrvp | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_07=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | $s24AppClipDeveloperSettings0C24DiagnosticsView_PreviewsV8previewsQrvpZ | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_08=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | _TtC24AppClipDeveloperSettings29DeveloperDiagnosticsViewModel | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_09=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | _TtC24AppClipDeveloperSettings41DeveloperDiagnosticsViewControllerFactory | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_10=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | appClipsDeveloperDiagnosticsViewController | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_11=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | developer_diagnostics | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_12=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | DeveloperDiagnosticsView | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_13=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | DeveloperDiagnosticsView_Previews | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_14=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | DeveloperDiagnosticsViewControllerFactory | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_15=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | DeveloperDiagnosticsViewModel | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_16=score:12 | Settings/AppClipDeveloperSettings | Developer / Diagnostics | universalLinksDeveloperDiagnosticsViewController | /System/Library/PreferenceBundles/AppClipDeveloperSettings.bundle/AppClipDeveloperSettings
finding_17=score:12 | Settings/DeveloperSettings | Developer / Diagnostics | developer_diagnostics | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DeveloperSettings
finding_18=score:12 | Settings/DeveloperSettings | Developer / Diagnostics | items[51].get = getWidgetKitDeveloperModeEnabled: | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DTSettings.plist
finding_19=score:12 | Settings/DeveloperSettings | Developer / Diagnostics | items[51].key = widgetKitDeveloperModeEnabled | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DTSettings.plist
finding_20=score:12 | Settings/DeveloperSettings | Developer / Diagnostics | items[51].label = WIDGETKIT_DEVELOPER_MODE_ENABLED | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DTSettings.plist
```

## Validation log
```text
build_rc=0
built_deb=packages/com.nightvibes.hidden_0.1.0_iphoneos-arm64.deb
package_name=com.nightvibes.hidden
package_version=0.1.0
package_arch=iphoneos-arm64
package_contents_begin
drwxr-xr-x 0/root            0 2026-08-24 00:02 .
drwxr-xr-x 0/root            0 2026-08-24 00:02 var
drwxr-xr-x 0/root            0 2026-08-24 00:02 var/jb
drwxr-xr-x 0/root            0 2026-08-24 00:02 var/jb/Applications
drwxr-xr-x 0/root            0 2026-08-24 00:02 var/jb/Applications/Hidden.app
-rwxr-xr-x 0/root       107024 2026-08-24 00:02 var/jb/Applications/Hidden.app/Hidden
-rw-r--r-- 0/root         1613 2026-08-24 00:02 var/jb/Applications/Hidden.app/Info.plist
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
24b591e11788a25247c5014bcc98b2f4afcff3855d75a7a67c88b89dc0698173  Hidden-0.1.0-rootless.deb
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
