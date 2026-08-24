# Hidden Build / Device Status

- Run: 32676912310
- Commit: 31141b38917a41dd0af04f514057fb122ac6d8c0
- Build step: success
- Device step: success

## Device proof and scan summary
```text
checkpoint=wait_for_device_recovery
recovery_connect_attempt=1
checkpoint=kill_old_scan
Warning: Permanently added '100.116.117.65' (ED25519) to the list of known hosts.
(Reading database ... 25607 files and directories currently installed.)
Preparing to unpack .../Hidden-0.1.0-rootless.deb ...
Unpacking com.nightvibes.hidden (0.1.0) over (0.1.0) ...
Setting up com.nightvibes.hidden (0.1.0) ...
Processing triggers for uikittools (2.1.8) ...
installed_version=0.1.0
hidden_pid=7230
package_payload=pass
homescreen_launch=pass
checkpoint=scan_poll
scan_poll_4=READY
scan_schema=4
scan_total_findings=3975
scan_reported_findings=1000
scan_elapsed_seconds=11.881286978721619
scan_os=Version 16.7.11 (Build 20H360)
scan_category_counts={"Capability Gate":1006,"Experimental":77,"Feature Gate":431,"Hidden UI":108,"Internal / Developer":678,"System Signal":1675}
scan_top_targets=Settings/MusicSettings, Settings/DeveloperSettings, Settings/CameraSettings, Settings/AccessibilitySettings, MobileSMS, Preferences, Settings/AppClipDeveloperSettings, AppStore, Settings/MapsSettings, HomeUIService, Settings/NotificationsSettings, Settings/CallForwardingTelephonySettings, Settings/AccessoryDeveloperSettings, Settings/BatteryUsageUI, SpringBoard
finding_01=score:35 | Settings/AccessibilitySettingsSearch | Internal / Developer | Gate items[0] / label=ACCESSIBILITY / requiredCapabilities=(     accessibility ) | /System/Library/PreferenceManifestsInternal/AccessibilitySettingsSearch.bundle/SettingsSearchManifest-com.apple.AccessibilitySettings.plist
finding_02=score:35 | Settings/AccessibilitySettingsSearch | Internal / Developer | Gate items[101] / label=HOVERTEXT / requiredCapabilities=(     HoverText ) | /System/Library/PreferenceManifestsInternal/AccessibilitySettingsSearch.bundle/SettingsSearchManifest-com.apple.AccessibilitySettings.plist
finding_03=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[0] / label=TOUCH_ID__PASSCODE / requiredCapabilities=(     "touch-id" ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
finding_04=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[0] / label=TV / requiredCapabilities=(         {         "green-tea" = 0;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_05=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[10] / label=WALLET / requiredCapabilities=(     shoebox ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
finding_06=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[11] / label=RETURN_MISSED_CALLS / requiredCapabilities=(         {         venice = 1;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
finding_07=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[13] / label=USE_APPLE_WATCH_TO_UNLOCK / requiredCapabilities=(     8olRm6C1xqr7AJGpLRnpSw ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
finding_08=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[1] / label=AUTOMATIC_DOWNLOADS / requiredCapabilities=(     "cellular-data" ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.mobilestoresettings.plist
finding_09=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[1] / label=FACE_ID__PASSCODE / requiredCapabilities=(     8olRm6C1xqr7AJGpLRnpSw ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
finding_10=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[1] / label=VIDEOS / requiredCapabilities=(         {         "green-tea" = 1;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_11=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[2] / label=BATTERY_SAVER_MODE / requiredCapabilities=(     "f+PE44W6AO2UENJk3p2s5A" ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.settings.BatteryUsageUI.plist
finding_12=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[2] / label=PASSCODE / requiredCapabilities=(         {         8olRm6C1xqr7AJGpLRnpSw = 0;         "touch-id" = 0;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
finding_13=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[2] / label=USE_CELLULAR_DATA_FOR_PLAYBACK / requiredCapabilities=(         {         "cellular-data" = 1;         "green-tea" = 0;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_14=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[3] / label=APP_DOWNLOADS / requiredCapabilities=(     "cellular-data" ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.mobilestoresettings.plist
finding_15=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[3] / label=BATTERY_HEALTH_MODE / requiredCapabilities=(         {         ipad = 0;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.settings.BatteryUsageUI.plist
finding_16=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[3] / label=USE_CELLULAR_DATA_FOR_PLAYBACK / requiredCapabilities=(         {         "cellular-data" = 1;         "green-tea" = 1;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_17=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[4] / label=PLAYBACK_QUALITY / requiredCapabilities=(         {         "green-tea" = 0;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_18=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[5] / label=PLAYBACK_QUALITY / requiredCapabilities=(         {         "green-tea" = 1;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_19=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[6] / label=PURCHASES_AND_RENTALS / requiredCapabilities=(         {         "green-tea" = 0;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-com.apple.tvsettings.plist
finding_20=score:35 | Settings/PreferencesManifests | Internal / Developer | Gate items[6] / label=VOICE_DIAL / requiredCapabilities=(         {         "any-telephony" = 1;         "voice-control" = 1;     } ) | /System/Library/PreferenceManifestsInternal/PreferencesManifests.bundle/SettingsSearchManifest-Passcode.plist
system_scan_report=pass
device_proof=success
```

## Validation log
```text
build_rc=0
package_name=com.nightvibes.hidden
package_version=0.1.0
package_arch=iphoneos-arm64
hidden-deb-root/var/jb/Applications/Hidden.app/Hidden: Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|PIE>
1db69b8642366dc250b1a3620872fa9321fbe6d1775e3556339f4013eb08795b  Hidden-0.1.0-rootless.deb
package_validation=success
```

## Build log tail
```text
[0;36m==> [1;39mCleaning…[m
[1;31m> [1;3;39mMaking all for application Hidden…[m
[0;35m==> [1;39mCopying resource directories into the application wrapper…[m
[0;32m==> [1;39mCompiling Sources/HiddenV2.m (arm64)…[m
[0;33m==> [1;39mLinking application Hidden (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for Hidden…[m
[0;34m==> [1;39mStripping Hidden (arm64)…[m
[0;34m==> [1;39mSigning Hidden…[m
[1;31m> [1;3;39mMaking stage for application Hidden…[m
[0;36m==> [1;36mNotice:[m Neither plutil, ply, or libplist-utils are installed, so XML plist files were not optimized.
dm.pl: building package `com.nightvibes.hidden:iphoneos-arm64' in `./packages/com.nightvibes.hidden_0.1.0_iphoneos-arm64.deb'
```
