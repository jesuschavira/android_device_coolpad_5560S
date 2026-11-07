# TWRP device tree for Coolpad Arise 5560S

| | |
|---|---|
| Device | Coolpad Arise 5560S (`ro.product.device=5560S`) |
| SoC | Qualcomm MSM8610 (Snapdragon 200), 2x Cortex-A7 |
| RAM | 512 MB |
| Display | 480x800, OTM8018B panel (MDP3) |
| Kernel | Stock Coolpad 3.4.0 (`3.4.0-g9b6969a-00634-g6af6a04`), prebuilt |
| Recovery partition | `mmcblk0p19`, 10 MB |

## Status

The **working TWRP 3.7.0_9-0 image** for this phone was made as a **port**:
the TWRP ramdisk of a Moto E 2014 (`condor`, also MSM8610) build combined with the
**stock Coolpad kernel and stock QCDT dt.img**, plus a `recovery.fstab` for the
Coolpad partition layout. It boots, mounts system/data/cache, backs up and flashes.

This repository turns that port into a buildable TWRP device tree:

- `prebuilt/zImage`, `prebuilt/dt.img` - extracted byte-for-byte from the working image
  (md5 `ee617978041ad89af38c5d8ed65c1368` / `a2bac6c6d607712af259edf31f5c8aff`).
- `recovery/root/etc/recovery.fstab` - the fstab used by the working image.
- `BoardConfig.mk` - boot image layout taken from the working image (page size 2048,
  kernel 0x8000, ramdisk 0x1000000, tags 0x100, LZMA ramdisk, same cmdline).

> **Note:** building TWRP from source with this tree has **not been tested yet**.
> The prebuilt image works; the tree reproduces its parameters.

## Kernel source

Coolpad never published the kernel source for the 5560S, so the kernel is prebuilt.
The version string points to a Qualcomm CAF msm-3.4 base (`g9b6969a`) with Coolpad changes.

## Build

```bash
# TWRP minimal manifest (omni-based), e.g. twrp-6.0 or twrp-7.1
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-7.1
repo sync
git clone https://github.com/<user>/android_device_coolpad_5560S device/coolpad/5560S
. build/envsetup.sh
lunch omni_5560S-eng
make recoveryimage
```

## Flashing

The Coolpad bootloader does not accept normal `fastboot flash`. Flash from an existing
TWRP or a rooted ROM with `dd`:

```
dd if=recovery.img of=/dev/block/platform/msm_sdcc.1/by-name/recovery bs=2048
```

Keys: **Vol+ and Vol- + Power** to boot into recovery.

## Credits

- TeamWin - TWRP
- The builder(s) of the Moto E 2014 (condor) TWRP 3.7.0_9-0 / OmniROM 5.1.1 image used as the base
- Jesus Chavira - Coolpad 5560S port and testing
