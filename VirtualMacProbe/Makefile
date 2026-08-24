ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = vmhvprobe
vmhvprobe_FILES = hvprobe.c
vmhvprobe_CFLAGS = -Wall -Wextra
vmhvprobe_CODESIGN_FLAGS = -Sentitlements.plist
vmhvprobe_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
