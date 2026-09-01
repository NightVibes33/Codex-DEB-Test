ARCHS = arm64
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ByeTunes16
ByeTunes16_FILES = Tweak.xm BTClient.m BTManager.m
ByeTunes16_FRAMEWORKS = UIKit UniformTypeIdentifiers
ByeTunes16_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations
ByeTunes16_INSTALL_TARGET_PROCESSES = Music

TOOL_NAME = byetunes16d
byetunes16d_FILES = daemon/main.m daemon/BTImporter.m daemon/BTImporter+Full.m daemon/BTMetadataService.m
byetunes16d_FRAMEWORKS = Foundation AVFoundation CoreMedia
byetunes16d_LIBRARIES = sqlite3
byetunes16d_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations
byetunes16d_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk

before-package::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/LaunchDaemons
	@cp layout/Library/LaunchDaemons/com.nightvibes.byetunes16d.plist $(THEOS_STAGING_DIR)/Library/LaunchDaemons/
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	@cp packaging/postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst
	@cp packaging/prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm
	@chmod 0755 $(THEOS_STAGING_DIR)/DEBIAN/postinst $(THEOS_STAGING_DIR)/DEBIAN/prerm
