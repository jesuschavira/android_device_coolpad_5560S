# Coolpad Arise 5560S (MSM8610) - TWRP
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, vendor/omni/config/common.mk)

# Prebuilt stock Coolpad kernel (no public kernel source for this device)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/zImage:kernel

PRODUCT_DEVICE := 5560S
PRODUCT_NAME := omni_5560S
PRODUCT_BRAND := Coolpad
PRODUCT_MODEL := 5560S
PRODUCT_MANUFACTURER := Coolpad
