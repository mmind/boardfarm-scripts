#!/bin/bash -e

# FIXME: move to FIT image
build_uimage() {
	ARCH=arm32
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
	mkimage -f /home/devel/nfs/kernel/$2-kernel.its /home/devel/nfs/kernel/tmp/$2-vmlinux.uimg > /dev/null
	cp /home/devel/nfs/kernel/tmp/$2-vmlinux.uimg /home/devel/tftp/hstuebner/$2.vmlinuz
	rm /home/devel/nfs/kernel/tmp/$2-vmlinux.uimg
}


ARCH=arm32
tar -C /home/devel/nfs/kernel/$ARCH/dtbs -xzf /home/devel/nfs/kernel/$ARCH/dtbs-$ARCH.tar.gz
ARCH=arm64
tar -C /home/devel/nfs/kernel/$ARCH/dtbs -xzf /home/devel/nfs/kernel/$ARCH/dtbs-$ARCH.tar.gz

build_netboot arm64 gru
build_netboot arm64 r88
build_netboot arm64 rk3399evb
build_netboot arm32 pinky
build_netboot arm32 brain
build_netboot arm32 rock

build_uimage_netboot rk3036 kylin

# extract modules into nfsroot instances
for i in `cat /home/devel/nfs/instances | grep -v "^#"`; do
	ARCH=`echo $i | cut -d ":" -f 2`
	INST=`echo $i | cut -d ":" -f 1`

	if [ -d /home/devel/nfs/rootfs-$INST/lib/modules ]; then
		set +e
		rm -rf /home/devel/nfs/rootfs-$INST/lib/modules/*
		set -e
	else
		sudo mkdir /home/devel/nfs/rootfs-$INST/lib/modules
		sudo chown hstuebner.hstuebner /home/devel/nfs/rootfs-$INST/lib/modules
	fi

	echo "unpacking $ARCH modules for $INST"
	tar -C /home/devel/nfs/rootfs-$INST/lib/modules -xzf /home/devel/nfs/kernel/$ARCH/modules-$ARCH.tar.gz
done


