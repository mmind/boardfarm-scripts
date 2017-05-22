#!/bin/bash -e

build_initramfs() {
	local ARCH=$1
	local INST=$2
	local BUILDPLACE=/home/devel/nfs/rootfs-$INST

	if [ ! -d $BUILDPLACE ]; then
		echo "instace $INST not found"
		exit 1
	fi

	if [ ! -f /home/devel/nfs/kernel/$ARCH/kernel.release ]; then
		echo "kernel.release missing"
		exit 1
	fi

	local KVER=`cat /home/devel/nfs/kernel/$ARCH/kernel.release`
	local CHROOTEXEC="/usr/sbin/chroot $BUILDPLACE "

	echo "Updating initramfs of $INST $KVER"
	set +e
	$CHROOTEXEC update-initramfs -d -k $KVER
	set -e
	$CHROOTEXEC update-initramfs -c -k $KVER

	if [ ! -f $BUILDPLACE/boot/initrd.img-$KVER ]; then
		echo "initramfs creation failed"
		exit 1
	fi

	if [ -f $BUILDPLACE/boot/initrd.img ]; then
		rm $BUILDPLACE/boot/initrd.img
	fi
	mv $BUILDPLACE/boot/initrd.img-$KVER $BUILDPLACE/boot/initrd.img
}

build_initramfs $1 $2
