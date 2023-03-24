#!/bin/bash -e

. /home/devel/hstuebner/bootfarm/server/bootfarm-helpers.sh

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
	local INST=$2

	if [ ! -f /home/devel/nfs/kernel/$INST-kernel.its ]; then
		echo "$INST: no netboot image to build"
		return
	fi

	echo "$INST: building netboot image"
	mkimage -D "-q" -f /home/devel/nfs/kernel/$INST-kernel.its /home/devel/nfs/kernel/tmp/$INST-vmlinux.uimg > /dev/null
	cp /home/devel/nfs/kernel/tmp/$INST-vmlinux.uimg /home/devel/tftp/hstuebner/$INST.vmlinuz
	rm /home/devel/nfs/kernel/tmp/$INST-vmlinux.uimg
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

if [ "$#" = "1" ]; then
	TARGET=$1
else
	TARGET="*"
fi

extract_dtbs arm32
extract_dtbs arm64
extract_dtbs riscv64

# extract modules into nfsroot instances
for i in `cat /home/devel/nfs/instances | grep -v "^#"`; do
	ARCH=`echo $i | cut -d ":" -f 2`
	INST=`echo $i | cut -d ":" -f 1`

	if [ "$TARGET" != "*" ] && [ "$TARGET" != "$ARCH" ] && [ "$TARGET" != "$INST" ]; then
		echo "$INST: skipping image ($ARCH != $TARGET)"
		continue
	fi

	if [ ! -d /home/devel/nfs/rootfs-$INST ]; then
		echo "$INST: skipping image (no rootfs)"
		continue
	fi

	setup_modules $ARCH $INST /home/devel/nfs/rootfs-$INST
	unpack_modules $ARCH $INST /home/devel/nfs/rootfs-$INST
	install_config $ARCH $INST /home/devel/nfs/rootfs-$INST

	# only build initramfs for arm64 and riscv64
	if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "riscv64" ]; then
		sudo /home/devel/hstuebner/bootfarm/server/rebuild-initramfs.sh $ARCH $INST
	fi

	build_netboot $ARCH $INST
	build_cmdscr $ARCH $INST
done
