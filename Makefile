THEOS_DEVICE_IP=192.168.63.58

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TARGET = iphone:11.2:13
ARCHS = armv7 arm64 arm64e
PACKAGE_VERSION = 1.0
DEBUG = 1
FINALPACKAGE = 0

PREFS_PATH = colormebaddge13prefs

TWEAK_NAME = ColorMeBaddge13

$(TWEAK_NAME)_FILES = $(wildcard *.xm *.m external/*/*.m) $(PREFS_PATH)/external/HRColorPicker/UIColor+HRColorPickerHexColor.m
$(TWEAK_NAME)_CFLAGS += -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += $(PREFS_PATH)
include $(THEOS_MAKE_PATH)/aggregate.mk
