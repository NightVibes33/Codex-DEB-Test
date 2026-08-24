# Hidden Build / Device Status

- Run: 32676491023
- Commit: 7e41ca70a122cd12e152f34d7319efe226707575
- Build step: success
- Device step: success

## Device proof and scan summary
```text
checkpoint=wait_for_device_recovery
recovery_wait_attempt=12
recovery_connect_attempt=17
checkpoint=kill_old_scan
Warning: Permanently added '100.116.117.65' (ED25519) to the list of known hosts.
(Reading database ... 25607 files and directories currently installed.)
Preparing to unpack .../Hidden-0.1.0-rootless.deb ...
Unpacking com.nightvibes.hidden (0.1.0) over (0.1.0) ...
Setting up com.nightvibes.hidden (0.1.0) ...
Processing triggers for uikittools (2.1.8) ...
installed_version=0.1.0
hidden_pid=7169
package_payload=pass
homescreen_launch=pass
checkpoint=scan_poll
scan_poll_3=READY
scan_schema=3
scan_total_findings=5244
scan_reported_findings=1000
scan_elapsed_seconds=6.510810017585754
scan_os=Version 16.7.11 (Build 20H360)
scan_category_counts={"Capability Gate":251,"Developer / Diagnostics":396,"Experimental":9,"Feature Flag":969,"Hidden UI":3619}
scan_top_targets=Settings/AccessibilitySettings, SpringBoardUIServices (PrivateFramework), SpringBoard, Settings/DeveloperSettings, Settings/MusicSettings, Settings/AccessoryDeveloperSettings, Settings/CameraSettings, Settings/HearingSettings, MobileSMS, Settings/AppClipDeveloperSettings, Settings/EDGESettings, Settings/MobileSlideShowSettings, Settings/TVSettings, Settings/InternationalSettings, AppStore
finding_01=score:20 | Settings/DeveloperSettings | Developer / Diagnostics | Specifier items[51] / label=WIDGETKIT_DEVELOPER_MODE_ENABLED / key=widgetKitDeveloperModeEnabled / get=getWidgetKitDeveloperModeEnabled: / set=setWidgetKitDeveloperModeEnabled:specifier: / defaults=com.apple.duetexpertd | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DTSettings.plist
finding_02=score:20 | Settings/MusicSettings | Hidden UI | Specifier items[2] / label=SHOW_APPLE_MUSIC / key=UserRequestedSubscriptionHidden / defaults=com.apple.mobileipod / id=com.apple.Music:AppleMusicEnabled / postnotification=com.apple.mobileipod-prefsChanged | /System/Library/PreferenceBundles/MusicSettings.bundle/MusicSettings.plist
finding_03=score:19 | Settings/AccessibilitySettings | Hidden UI | Specifier items[1] / label=FILTER_COLOR_ENABLED / key=ColorFilterEnabled / get=accessibilityPreferenceForSpecifier: / set=accessibilitySetPreference:specifier: / defaults=com.apple.Accessibility | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/DisplayFilterColorSettings.plist
finding_04=score:19 | Settings/AccessibilitySettings | Hidden UI | Specifier items[7] / label=GUIDED_ACCESS_AX_FEATURES_TITLE / key=GuidedAccessEnableAXFeatures / get=accessibilityPreferenceForSpecifier: / set=accessibilitySetPreference:specifier: / id=GuidedAccessEnableAXFeatures | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/GuidedAccessSettings.plist
finding_05=score:19 | Settings/BluetoothSettings | Hidden UI | Specifier items[1] / label=BLUETOOTH / key=bluetooth-network / get=bluetoothEnabled: / set=setBluetoothEnabled:specifier: / defaults=com.apple.preferences.network / id=BLUETOOTH | /System/Library/PreferenceBundles/BluetoothSettings.bundle/Devices.plist
finding_06=score:19 | Settings/KeyboardSettings | Hidden UI | Specifier items[0] / label=AUTO_CONFIRMATION_OPTION / key=HandwritingAutoConfirmationEnabled / set=setKeyboardPreferenceValue:forSpecifier: / defaults=com.apple.InputModePreferences / id=HandwritingAutoConfirmationEnabled | /System/Library/PreferenceBundles/KeyboardSettings.bundle/Preferences_hwr.plist
finding_07=score:19 | Settings/KeyboardSettings | Hidden UI | Specifier items[11] / label=Enable Key Flicks / key=GesturesEnabled / set=setKeyboardPreferenceValue:forSpecifier: / defaults=com.apple.keyboard.preferences / id=GesturesEnabled | /System/Library/PreferenceBundles/KeyboardSettings.bundle/Preferences_base.plist
finding_08=score:19 | Settings/KeyboardSettings | Hidden UI | Specifier items[12] / label=Continuous_Path / key=KeyboardContinuousPathEnabled / get=readCPPreferenceValue: / set=setKeyboardPreferenceValue:forSpecifier: / defaults=com.apple.keyboard.ContinuousPath / id=KeyboardContinuousPathEnabled | /System/Library/PreferenceBundles/KeyboardSettings.bundle/Preferences_base.plist
finding_09=score:19 | Settings/MusicSettings | Hidden UI | Specifier items[26] / label=AUTOMATIC_DOWNLOAD / key=DownloadOnAddToLibrary / get=isAutomaticDownloadsEnabled: / set=setAutomaticDownloadsEnabled:specifier: / defaults=com.apple.Music / id=com.apple.Music:MusicAutomaticDownload / postnotifi | /System/Library/PreferenceBundles/MusicSettings.bundle/MusicSettings.plist
finding_10=score:18 | Settings/MobileSlideShowSettings | Hidden UI | Specifier items[24] / label=HIDDEN_ALBUM_SWITCH / key=HiddenAlbumVisible / defaults=com.apple.mobileslideshow / id=PhotosHiddenAlbumSwitch / postnotification=com.apple.mobileslideshow.PreferenceChanged | /System/Library/PreferenceBundles/MobileSlideShowSettings.bundle/Photos.plist
finding_11=score:18 | Settings/SecuritySettings | Developer / Diagnostics | Specifier items[1] / label=DEV_MODE_TOGGLE_PROMPT / get=readPreferenceValue: / set=setPreferenceValue:forSpecifier: / id=DeveloperModeToggle | /System/Library/PreferenceBundles/SecuritySettings.bundle/DeveloperMode.plist
finding_12=score:17 | Settings/AccessibilitySettings | Hidden UI | Specifier items[1] / label=GUIDED_ACCESS_TITLE / key=EnableGuidedAccess / get=accessibilityPreferenceForSpecifier: / set=accessibilitySetPreference:specifier: / defaults=com.apple.Accessibility / id=EnableGuidedAccess | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/GuidedAccessSettings.plist
finding_13=score:17 | Settings/AccessibilitySettings | Hidden UI | Specifier items[1] / label=QUICK_SPEAK_TITLE / key=QuickSpeakEnabled / get=quickSpeakEnabled: / set=setQuickSpeakEnabled:specifier: | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/SpeechSettings.plist
finding_14=score:17 | Settings/AccessibilitySettings | Hidden UI | Specifier items[1] / label=ZOOM_TITLE / key=ZoomTouchEnabled / get=zoomTouchEnabled: / set=setZoomTouchEnabled:specifier: / id=ZoomTouchEnabled | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/ZoomSettings.plist
finding_15=score:17 | Settings/AccessibilitySettings | Hidden UI | Specifier items[6] / label=FOCUS_RING_LARGE_FOCUS_RING / key=FKALargeFocusRingEnabled / get=largeFocusRingEnabled: / set=setLargeFocusRingEnabled:specifier: / id=FKALargeFocusRingEnabled | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/FullKeyboardAccessSettings.plist
finding_16=score:17 | Settings/AccessibilitySettings | Hidden UI | Specifier items[7] / label=FOCUS_RING_FOCUS_RING_HIGH_CONTRAST / key=FKAFocusRingHighContrastEnabled / get=focusRingHighContrastEnabled: / set=setFocusRingHighContrastEnabled:specifier: / id=FKAFocusRingHighContrastEnabled | /System/Library/PreferenceBundles/AccessibilitySettings.bundle/FullKeyboardAccessSettings.plist
finding_17=score:17 | Settings/DeveloperSettings | Hidden UI | Specifier items[7] / label=ENABLE_UI_AUTOMATION / key=UIAutomationEnabled / defaults=com.apple.UIAutomation / id=UIAGroup / postnotification=com.apple.springboard.appIconVisibilityPreferencesChanged | /System/Library/PreferenceBundles/DeveloperSettings.bundle/DTSettings.plist
finding_18=score:17 | Settings/KeyboardSettings | Hidden UI | Specifier items[3] / label=Enable Caps Lock / key=KeyboardCapsLock / set=setKeyboardPreferenceValue:forSpecifier: / defaults=com.apple.keyboard.preferences / id=KeyboardCapsLock | /System/Library/PreferenceBundles/KeyboardSettings.bundle/Preferences_base.plist
finding_19=score:17 | Settings/MobileSlideShowSettings | Hidden UI | Specifier items[22] / label=CONTENT_PRIVACY_SWITCH_FACEID / key=ContentPrivacyEnabled / get=contentPrivacyEnabled: / set=contentPrivacyEnableWasToggled:specifier: / defaults=com.apple.mobileslideshow / id=PhotosContentPrivacySwitch | /System/Library/PreferenceBundles/MobileSlideShowSettings.bundle/Photos.plist
finding_20=score:17 | Settings/MusicSettings | Hidden UI | Specifier items[30] / label=USE_LISTENING_HISTORY / key=MPCPlaybackPrivateListeningEnabled / get=useListeningHistory: / set=setUseListeningHistory:specifier: / defaults=com.apple.mediaplaybackcore / id=com.apple.Music:PrivateListening / pos | /System/Library/PreferenceBundles/MusicSettings.bundle/MusicSettings.plist
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
0c92fa177672aaa6e0114709275393441c811fd8326473ace4c0b75b9bb7607e  Hidden-0.1.0-rootless.deb
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
