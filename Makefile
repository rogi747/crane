TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES := CraneManager
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = CraneManager

CraneManager_FILES = $(wildcard Sources/*.m) $(wildcard Sources/*.mm)
CraneManager_CFLAGS = -fobjc-arc -ISources
CraneManager_FRAMEWORKS = UIKit Foundation Security
CraneManager_PRIVATE_FRAMEWORKS = MobileCoreServices
CraneManager_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS)/makefiles/application.mk
