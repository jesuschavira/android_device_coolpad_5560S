LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),5560S)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
