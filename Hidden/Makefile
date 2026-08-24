ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Hidden

Hidden_FILES = Sources/HiddenV2.m
Hidden_FRAMEWORKS = UIKit Foundation
Hidden_CFLAGS = -fobjc-arc -Wall -Wextra
Hidden_CODESIGN_FLAGS = -SHidden.entitlements
Hidden_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
