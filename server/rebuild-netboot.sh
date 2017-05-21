#!/bin/bash -e

# FIXME: move to FIT image
build_uimage() {
	local ARCH=arm32
	echo "building $1-$2"
	#mkimage -f kylin-kernel.its kylin-vmlinux.uimg > /dev/null

	cat /home/devel/nfs/kernel/$ARCH/zImage /home/devel/nfs/kernel/$ARCH/dtbs/$1-$2.dtb > /home/devel/nfs/kernel/tmp/$2.krnl
	mkimage -A arm -O linux -T kernel -C none -a 0x60800800 -d /home/devel/nfs/kernel/tmp/$2.krnl /home/devel/tftp/hstuebner/$2.vmlinuz
	rm /home/devel/nfs/kernel/tmp/$2.krnl
}

build_uimage_netboot() {
	build_uimage $1 $2
}

build_netboot() {
	echo "building netboot image for $2"
	mkimage -D "-q" -f /home/devel/nfs/kernel/$2-kernel.its /home/devel/nfs/kernel/tmp/$2-vmlinux.uimg > /dev/null
	cp /home/devel/nfs/kernel/tmp/$2-vmlinux.uimg /home/devel/tftp/hstuebner/$2.vmlinuz
	rm /home/devel/nfs/kernel/tmp/$2-vmlinux.uimg
}

build_cmdscr() {
	if [ -f /home/devel/tftp/hstuebner/$2.cmd ]; then
		echo "setenv bootargs `cat /home/devel/tftp/hstuebner/$2.cmd`" > /home/devel/tftp/hstuebner/$2.bootargs
		mkimage -T script -C none -n 'Set bootargs' -d /home/devel/tftp/hstuebner/$2.bootargs /home/devel/tftp/hstuebner/$2.scr >/dev/null
		rm /home/devel/tftp/hstuebner/$2.bootargs
	fi
}

extract_dtbs() {
	local ARCH=$1
	if [ ! -d /home/devel/nfs/kernel/$ARCH/dtbs ]; then
		mkdir /home/devel/nfs/kernel/$ARCH/dtbs
	fi

	tar -C /home/devel/nfs/kernel/$ARCH/dtbs -xzf /home/devel/nfs/kernel/$ARCH/dtbs-$ARCH.tar.gz
}

unpack_modules() {
	local ARCH=$1
	local INST=$2
	local TARGET=$3

	if [ -d /home/devel/nfs/kernel/$INST ]; then
		echo "unpacking $INST modules for $TARGET"
		tar -C $TARGET/lib/modules -xzf /home/devel/nfs/kernel/$INST/modules-$INST.tar.gz
	else
		echo "unpacking $ARCH modules for $TARGET"
		tar -C $TARGET/lib/modules -xzf /home/devel/nfs/kernel/$ARCH/modules-$ARCH.tar.gz
	fi
}

if [ "$#" = "1" ]; then
	TARGET=$1
else
	TARGET="*"
fi

extract_dtbs arm32
extract_dtbs arm64

# extract modules into nfsroot instances
for i in `cat /home/devel/nfs/instances | grep -v "^#"`; do
	ARCH=`echo $i | cut -d ":" -f 2`
	INST=`echo $i | cut -d ":" -f 1`

	if [ "$TARGET" != "*" ] && [ "$TARGET" != "$ARCH" ] && [ "$TARGET" != "$INST" ]; then
		echo "skipping image for $INST ($ARCH != $TARGET)"
		continue
	fi

	build_netboot $ARCH $INST
	build_cmdscr $ARCH $INST

	if [ -d /home/devel/nfs/rootfs-$INST/lib/modules ]; then
		set +e
		rm -rf /home/devel/nfs/rootfs-$INST/lib/modules/*
		set -e
	else
		sudo mkdir /home/devel/nfs/rootfs-$INST/lib/modules
		sudo chown hstuebner.hstuebner /home/devel/nfs/rootfs-$INST/lib/modules
	fi

	unpack_modules $ARCH $INST /home/devel/nfs/rootfs-$INST
done


