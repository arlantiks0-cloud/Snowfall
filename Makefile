
TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Snowfall
BUNDLE_NAME = SnowfallPrefs

Snowfall_FILES = Tweak.xm
Snowfall_CFLAGS = -fobjc-arc
Snowfall_FRAMEWORKS = UIKit Foundation

SnowfallPrefs_FILES = SnowfallPrefs/SnowfallRootListController.m
SnowfallPrefs_FRAMEWORKS = UIKit PhotosUI
SnowfallPrefs_PRIVATE_FRAMEWORKS = Preferences
SnowfallPrefs_INSTALL_PATH = /Library/PreferenceBundles
SnowfallPrefs_CFLAGS = -fobjc-arc
SnowfallPrefs_RESOURCE_DIRS = SnowfallPrefs/Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
