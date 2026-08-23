ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TweakMedic
TweakMedic_FILES = app/main.m app/TMAppDelegate.m app/TMRootViewController.m app/TMClient.m
TweakMedic_FRAMEWORKS = UIKit Foundation
TweakMedic_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
TweakMedic_INSTALL_PATH = /Applications
TweakMedic_RESOURCE_DIRS = app/Resources
TweakMedic_CODESIGN_FLAGS = -Sapp/Entitlements.plist

TOOL_NAME = tweakmedicd tweakmedicctl
tweakmedicd_FILES = daemon/main.m daemon/TMScanner.m
tweakmedicd_FRAMEWORKS = Foundation CoreFoundation
tweakmedicd_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra -Idaemon -Icompat
tweakmedicd_LDFLAGS = -ldl
tweakmedicd_INSTALL_PATH = /usr/libexec

tweakmedicctl_FILES = cli/main.m
tweakmedicctl_FRAMEWORKS = Foundation
tweakmedicctl_CFLAGS = -fobjc-arc -Wall -Wextra
tweakmedicctl_INSTALL_PATH = /usr/bin

BUNDLE_NAME = TweakMedicPrefs
TweakMedicPrefs_FILES = prefs/TMRootListController.m
TweakMedicPrefs_FRAMEWORKS = UIKit
TweakMedicPrefs_PRIVATE_FRAMEWORKS = Preferences
TweakMedicPrefs_CFLAGS = -fobjc-arc -Wall -Wextra
TweakMedicPrefs_INSTALL_PATH = /Library/PreferenceBundles
TweakMedicPrefs_RESOURCE_DIRS = prefs/Resources

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-package::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons
	@cp packaging/com.nightvibes33.tweakmedicd.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	@cp packaging/TweakMedicPrefs.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/
