#!/bin/bash -e

build_initramfs() {
	local ARCH=$1
	local INST=$2
	local BUILDPLACE=/home/devel/nfs/rootfs-$INST

	if [ ! -d $BUILDPLACE ]; then
		echo "$INST: instance not found"
		exit 1
	fi

	if [ ! -f /home/devel/nfs/kernel/$ARCH/kernel.release ]; then
		echo "$ARCH: kernel.release missing"
		exit 1
	fi

	local KVER=`cat /home/devel/nfs/kernel/$ARCH/kernel.release`
	local CHROOTEXEC="/usr/sbin/chroot $BUILDPLACE "

	echo "$INST: creating initramfs for $KVER"
	set +e
	$CHROOTEXEC update-initramfs -d -k $KVER >/dev/null 2>&1
	set -e
	$CHROOTEXEC update-initramfs -c -k $KVER >/dev/null

	if [ ! -f $BUILDPLACE/boot/initrd.img-$KVER ]; then
		echo "$INST: initramfs creation failed"
		exit 1
	fi

	if [ -f $BUILDPLACE/boot/initrd.img ]; then
		rm $BUILDPLACE/boot/initrd.img
	fi
	mv $BUILDPLACE/boot/initrd.img-$KVER $BUILDPLACE/boot/initrd.img
}

build_initramfs $1 $2
