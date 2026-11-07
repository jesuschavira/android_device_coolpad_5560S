#!/bin/sh
# Runs once from /etc/inittab (sysinit) after switch_root from the initramfs.
mount -o remount,rw / 2>/dev/null
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t tmpfs -o mode=0755,size=16m tmpfs /run
mount -t tmpfs -o mode=1777,size=32m tmpfs /tmp
[ -d /dev/pts ] || { mkdir -p /dev/pts; mount -t devpts devpts /dev/pts; }
echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s
hostname "$(cat /etc/hostname)"
ifconfig lo 127.0.0.1 up
# USB net was brought up by the initramfs (rndis); make sure it is still there
for i in usb0 rndis0; do
  [ -d /sys/class/net/$i ] && ifconfig $i 192.168.7.2 netmask 255.255.255.0 up && break
done
# key-only SSH if the image was built with a public key and no password
OPTS=""; [ -e /etc/dropbear/nopassword ] && OPTS="-s -g"
echo "$OPTS" > /run/dropbear.opts
echo "alpine up: $(uname -a)" > /run/boot.log
