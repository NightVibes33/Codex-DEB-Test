# TweakMedic Device Status

- Run: 32670880841
- Commit: 406522c24daa15929d275a4a7cdc78a480907f04
- Device step: failure

## Device proof
```text
Warning: Permanently added '100.116.117.65' (ED25519) to the list of known hosts.
(Reading database ... 25603 files and directories currently installed.)
Preparing to unpack .../TweakMedic-1.0.0-rootless.deb ...
Unpacking com.nightvibes33.tweakmedic (1.0.0) over (1.0.0) ...
Setting up com.nightvibes33.tweakmedic (1.0.0) ...
Processing triggers for uikittools (2.1.8) ...
```

## Build log tail
```text
[0;36m==> [1;39mCleaning…[m
[1;31m> [1;3;39mMaking all for application TweakMedic…[m
[0;35m==> [1;39mCopying resource directories into the application wrapper…[m
[0;32m==> [1;39mCompiling app/TMClient.m (arm64)…[m
[0;32m==> [1;39mCompiling app/main.m (arm64)…[m
[0;32m==> [1;39mCompiling app/TMAppDelegate.m (arm64)…[m
[0;32m==> [1;39mCompiling app/TMRootViewController.m (arm64)…[m
[0;33m==> [1;39mLinking application TweakMedic (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for TweakMedic…[m
[0;34m==> [1;39mStripping TweakMedic (arm64)…[m
[0;34m==> [1;39mSigning TweakMedic…[m
[1;31m> [1;3;39mMaking all for tool tweakmedicd…[m
[0;32m==> [1;39mCompiling daemon/main.m (arm64)…[m
[0;32m==> [1;39mCompiling daemon/TMScanner.m (arm64)…[m
[0;33m==> [1;39mLinking tool tweakmedicd (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for tweakmedicd…[m
[0;34m==> [1;39mStripping tweakmedicd (arm64)…[m
[0;34m==> [1;39mSigning tweakmedicd…[m
[1;31m> [1;3;39mMaking all for tool tweakmedicctl…[m
[0;32m==> [1;39mCompiling cli/main.m (arm64)…[m
[0;33m==> [1;39mLinking tool tweakmedicctl (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for tweakmedicctl…[m
[0;34m==> [1;39mStripping tweakmedicctl (arm64)…[m
[0;34m==> [1;39mSigning tweakmedicctl…[m
[1;31m> [1;3;39mMaking all for bundle TweakMedicPrefs…[m
[0;35m==> [1;39mCopying resource directories into the bundle wrapper…[m
[0;32m==> [1;39mCompiling prefs/TMRootListController.m (arm64)…[m
[0;33m==> [1;39mLinking bundle TweakMedicPrefs (arm64)…[m
[0;34m==> [1;39mGenerating debug symbols for TweakMedicPrefs…[m
[0;34m==> [1;39mStripping TweakMedicPrefs (arm64)…[m
[0;34m==> [1;39mSigning TweakMedicPrefs…[m
[1;31m> [1;3;39mMaking stage for application TweakMedic…[m
[1;31m> [1;3;39mMaking stage for tool tweakmedicd…[m
[1;31m> [1;3;39mMaking stage for tool tweakmedicctl…[m
[1;31m> [1;3;39mMaking stage for bundle TweakMedicPrefs…[m
[0;36m==> [1;36mNotice:[m Neither plutil, ply, or libplist-utils are installed, so XML plist files were not optimized.
dm.pl: building package `com.nightvibes33.tweakmedic:iphoneos-arm64' in `./packages/com.nightvibes33.tweakmedic_1.0.0_iphoneos-arm64.deb'
```
