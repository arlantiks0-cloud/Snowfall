TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Snowfall

Snowfall_FILES = Tweak.xm
Snowfall_CFLAGS = -fobjc-arc
Snowfall_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
