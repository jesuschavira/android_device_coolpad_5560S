#!/usr/bin/env python3
"""Build linux-minimal.img for the Coolpad 5560S.

Pure Python: no cpio / mkbootimg needed. Produces an Android boot image v0
(same layout as BoardConfig.mk: page 2048, kernel 0x8000, ramdisk 0x1000000,
tags 0x100, QCDT dt.img) containing the stock kernel + a BusyBox initramfs.

    python3 pack.py                # -> out/linux-minimal.img
    python3 pack.py --busybox PATH # use a local static ARMv7 busybox
"""
import argparse, gzip, hashlib, os, struct, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PREBUILT = os.path.join(HERE, "..", "prebuilt")
BB_URL = "https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l"
BB_SHA256 = "cd04052b8b6885f75f50b2a280bfcbf849d8710c8e61d369c533acf307eda064"
CMDLINE = ("console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom "
           "user_debug=31 msm_rtb.filter=0x37 download_mode=0 quiet androidboot.selinux=permissive")
PAGE, KERNEL_ADDR, RAMDISK_ADDR, TAGS_ADDR = 2048, 0x8000, 0x1000000, 0x100
MAX_SIZE = 10 * 1024 * 1024  # boot/recovery partition size


def get_busybox(path):
    if not path:
        path = os.path.join(HERE, "out", "busybox-armv7l")
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            print("downloading busybox ...")
            urllib.request.urlretrieve(BB_URL, path)
    data = open(path, "rb").read()
    h = hashlib.sha256(data).hexdigest()
    if h != BB_SHA256:
        sys.exit(f"busybox sha256 mismatch: {h}")
    return data


def cpio_newc(entries):
    """entries: list of (name, mode, data). Returns a cpio 'newc' archive."""
    out, ino = bytearray(), 1
    def add(name, mode, data):
        nonlocal ino
        nm = name.encode() + b"\0"
        hdr = "070701" + "".join("%08X" % v for v in (
            ino, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(nm), 0))
        ino += 1
        out.extend(hdr.encode()); out.extend(nm)
        out.extend(b"\0" * (-len(out) % 4))
        out.extend(data); out.extend(b"\0" * (-len(out) % 4))
    for e in entries:
        add(*e)
    add("TRAILER!!!", 0, b"")
    return bytes(out)


def build_initramfs(bb):
    init = open(os.path.join(HERE, "init"), "rb").read()
    DIR, REG, LNK = 0o040755, 0o100755, 0o120777
    ents = [(d, DIR, b"") for d in ("bin", "sbin", "dev", "proc", "sys", "tmp", "etc", "mnt", "usr", "usr/bin")]
    ents += [("bin/busybox", REG, bb), ("init", REG, init),
             ("bin/sh", LNK, b"busybox"),
             ("etc/mdev.conf", 0o100644, b"")]
    return gzip.compress(cpio_newc(ents), 9, mtime=0)


def pad(b):
    return b + b"\0" * (-len(b) % PAGE)


def mkbootimg(kernel, ramdisk, dt, cmdline):
    ident = hashlib.sha1(kernel + ramdisk + dt).digest().ljust(32, b"\0")
    hdr = struct.pack("<8s10I16s512s32s1024s", b"ANDROID!",
                      len(kernel), KERNEL_ADDR, len(ramdisk), RAMDISK_ADDR,
                      0, 0x00f00000, TAGS_ADDR, PAGE, len(dt), 0,
                      b"coolpad-lnx", cmdline.encode(), ident, b"")
    return pad(hdr) + pad(kernel) + pad(ramdisk) + pad(dt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--busybox")
    ap.add_argument("--out", default=os.path.join(HERE, "out", "linux-minimal.img"))
    a = ap.parse_args()
    kernel = open(os.path.join(PREBUILT, "zImage"), "rb").read()
    dt = open(os.path.join(PREBUILT, "dt.img"), "rb").read()
    rd = build_initramfs(get_busybox(a.busybox))
    img = mkbootimg(kernel, rd, dt, CMDLINE)
    if len(img) > MAX_SIZE:
        sys.exit(f"image too big: {len(img)} > {MAX_SIZE}")
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    open(a.out, "wb").write(img)
    print(f"{a.out}: {len(img)} bytes (ramdisk {len(rd)} bytes)")
    print("md5", hashlib.md5(img).hexdigest())


if __name__ == "__main__":
    main()
