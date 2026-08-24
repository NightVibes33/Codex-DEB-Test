ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = vm-hvprobe
vm-hvprobe_FILES = hvprobe.c
vm-hvprobe_CFLAGS = -Wall -Wextra
vm-hvprobe_CODESIGN_FLAGS = -Sentitlements.plist
vm-hvprobe_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
