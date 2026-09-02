ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Misaka15Compat
Misaka15Compat_FILES = Tweak.xm
Misaka15Compat_FRAMEWORKS = Foundation UIKit
Misaka15Compat_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
Misaka15Compat_INSTALL_TARGET_PROCESSES = misaka

TOOL_NAME = misaka15launch
misaka15launch_FILES = launcher.m
misaka15launch_FRAMEWORKS = Foundation CoreFoundation
misaka15launch_CFLAGS = -fobjc-arc -Wall -Wextra -Werror
misaka15launch_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk
