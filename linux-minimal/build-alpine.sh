#!/usr/bin/env bash
# Build out/alpine.img: an ext4 image with Alpine (armv7) for the Coolpad 5560S.
# Copy it to the root of a FAT32 SD card; the initramfs loop-mounts it and
# switch_root's into it. Needs: bash curl tar mke2fs(>=1.43) openssl. Run as root
# (or under fakeroot) so files are owned by root inside the image.
#
#   ./build-alpine.sh [--size MB] [--pubkey ~/.ssh/id_ed25519.pub] [--password PW]
set -euo pipefail

ALPINE_VER=3.24.4; BRANCH=v3.24
ROOTFS=alpine-minirootfs-$ALPINE_VER-armv7.tar.gz
ROOTFS_SHA256=2054061dafea7fe4cd38015701ee77119e780dd0382d0c32fad56986fe31b699
MIRROR=https://dl-cdn.alpinelinux.org/alpine
PACKAGES="dropbear dropbear-scp"       # kept tiny: 512 MB RAM
SIZE_MB=256; PUBKEY=""; PASSWORD=""

while [ $# -gt 0 ]; do case $1 in
  --size) SIZE_MB=$2; shift 2;; --pubkey) PUBKEY=$2; shift 2;;
  --password) PASSWORD=$2; shift 2;; *) echo "unknown arg $1" >&2; exit 2;; esac; done

HERE=$(cd "$(dirname "$0")" && pwd); OUT=$HERE/out; WORK=$OUT/alpine-work; ROOT=$WORK/root
if [ "$(id -u)" != 0 ]; then
  command -v fakeroot >/dev/null || { echo "run as root or install fakeroot" >&2; exit 1; }
  exec fakeroot -- "$0" "$@"
fi
mkdir -p "$OUT"; rm -rf "$WORK"; mkdir -p "$ROOT"

dl() { [ -s "$OUT/$2" ] || curl -fsSL "$1" -o "$OUT/$2"; }
dl "$MIRROR/$BRANCH/releases/armv7/$ROOTFS" "$ROOTFS"
echo "$ROOTFS_SHA256  $OUT/$ROOTFS" | sha256sum -c -
tar -xzf "$OUT/$ROOTFS" -C "$ROOT"

# --- preinstall packages with the x86 static apk (no armv7 code is executed) ---
APKV=$(curl -fsSL "$MIRROR/$BRANCH/main/x86_64/" | grep -o 'apk-tools-static-[0-9][^"]*\.apk' | head -1)
dl "$MIRROR/$BRANCH/main/x86_64/$APKV" "$APKV"
mkdir -p "$WORK/apk" && tar -xzf "$OUT/$APKV" -C "$WORK/apk" 2>/dev/null
APK=$(find "$WORK/apk" -name 'apk.static' | head -1)
printf '%s/main\n%s/community\n' "$MIRROR/$BRANCH" "$MIRROR/$BRANCH" > "$ROOT/etc/apk/repositories"
"$APK" --root "$ROOT" --arch armv7 --keys-dir "$ROOT/etc/apk/keys" \
       --repositories-file "$ROOT/etc/apk/repositories" --no-progress \
       update
"$APK" --root "$ROOT" --arch armv7 --keys-dir "$ROOT/etc/apk/keys" \
       --repositories-file "$ROOT/etc/apk/repositories" --no-scripts --no-progress \
       add $PACKAGES

# --- boot configuration -----------------------------------------------------
install -m 0644 "$HERE/alpine/inittab" "$ROOT/etc/inittab"
install -m 0755 "$HERE/alpine/boot.sh" "$ROOT/etc/boot.sh"
echo coolpad > "$ROOT/etc/hostname"
mkdir -p "$ROOT"/{proc,sys,dev,run,tmp,mnt,root,etc/dropbear}
chmod 1777 "$ROOT/tmp"; chmod 700 "$ROOT/root"
printf 'nameserver 1.1.1.1\n' > "$ROOT/etc/resolv.conf"
grep -q '^/bin/sh$' "$ROOT/etc/shells" 2>/dev/null || echo /bin/sh >> "$ROOT/etc/shells"

if [ -n "$PUBKEY" ]; then
  mkdir -p "$ROOT/root/.ssh"; chmod 700 "$ROOT/root/.ssh"
  install -m 0600 "$PUBKEY" "$ROOT/root/.ssh/authorized_keys"
  echo "ssh: public key installed; password login stays disabled unless --password is given"
  [ -z "$PASSWORD" ] && : > "$ROOT/etc/dropbear/nopassword"
fi
if [ -z "$PUBKEY" ] && [ -z "$PASSWORD" ]; then
  PASSWORD=$(head -c 12 /dev/urandom | base64 | tr -d '/+=' | head -c 12)
  echo "generated root password (shown once): $PASSWORD"
fi
if [ -n "$PASSWORD" ]; then
  HASH=$(openssl passwd -6 "$PASSWORD")
  sed -i "s|^root:[^:]*:|root:$HASH:|" "$ROOT/etc/shadow"
fi

# --- ext4 image, populated straight from the directory (no loop mount needed) --
IMG=$OUT/alpine.img; rm -f "$IMG"
mke2fs -q -t ext4 -L alpine -O ^has_journal,^metadata_csum,^64bit -d "$ROOT" "$IMG" ${SIZE_MB}M
e2fsck -fn "$IMG" >/dev/null && echo "e2fsck: clean"
echo "$IMG: $(du -h "$IMG" | cut -f1) used of ${SIZE_MB} MB (sparse)"
echo "Copy it to the SD card root:  cp $IMG /path/to/SD/alpine.img"
