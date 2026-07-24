ARCHS = arm64
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = DarkGPT
DarkGPT_FILES = app/main.m app/DGAppDelegate.m app/DGViewController.m app/DGRootClient.m
DarkGPT_FRAMEWORKS = UIKit WebKit Security
DarkGPT_CFLAGS = -fobjc-arc -Wall -Wextra
DarkGPT_INSTALL_PATH = /Applications
DarkGPT_CODESIGN_FLAGS = -SEntitlements.plist

TOOL_NAME = darkgpt-rootd
darkgpt-rootd_FILES = daemon/main.m
darkgpt-rootd_FRAMEWORKS = Foundation
darkgpt-rootd_CFLAGS = -fobjc-arc -Wall -Wextra
darkgpt-rootd_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tool.mk

before-package::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons
	@cp packaging/com.nightvibes.darkgpt-rootd.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/
	@mkdir -p $(THEOS_STAGING_DIR)/usr/bin
	@cp packaging/darkgpt-approve $(THEOS_STAGING_DIR)/usr/bin/
	@chmod 0755 $(THEOS_STAGING_DIR)/usr/bin/darkgpt-approve

after-package::
	@./scripts/make-ipa.sh
