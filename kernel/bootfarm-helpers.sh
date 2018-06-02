
bootfarmip=192.168.140.1

create_icecc_env() {
	HOSTARCH=`uname -m`

	case "$HOSTARCH" in
		x86_64)
			ICECC_VERSION=`pwd`/__maintainer-scripts/toolchains/gcc7-amd64.tar.gz
			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc7-armhf.tar.gz=arm-linux-gnueabihf
			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc7-aarch64.tar.gz=aarch64-linux-gnu
			;;
		aarch64)
			ICECC_VERSION=`pwd`/__maintainer-scripts/toolchains/gcc7-aarch64.tar.gz
			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc7-armhf.tar.gz=arm-linux-gnueabihf
			;;
		*)
			echo "unsupported host architecture $HOSTARCH"
			exit 1
			;;
	esac
}

#
# Build kernel and modules for an architecture
# Cross-compilers are hardcoded for the standard packaged
# cross-compilers on a Debian system
#
# $1: target arch (arm32, arm64)
# $2: config to build (default oldconfig)
#
build_kernel() {
	create_icecc_env
	export ICECC_VERSION

	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			IMAGE=zImage
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			IMAGE=Image
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="oldconfig"
	else
		conf=$2
	fi

	if [ -d /usr/lib/icecc ] && [ -f __maintainer-scripts/toolchains/gcc7-amd64.tar.gz ]; then
		echo "using icecc"
		export PATH=/usr/lib/icecc/bin:$PATH
	fi

	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS KCPPFLAGS="-fno-pic -Wno-pointer-sign" O=_build-$1 $conf
	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS KCPPFLAGS="-fno-pic -Wno-pointer-sign" O=_build-$1 -j14 $IMAGE
	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS KCPPFLAGS="-fno-pic -Wno-pointer-sign" O=_build-$1 -j14 modules
	build_dtbs $1
}

#
# Build devicetrees for an architecture
#
# $1: target arch (arm32, arm64)
# $2: config to build (default oldconfig)
#
build_dtbs() {
	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="oldconfig"
	else
		conf=$2
	fi

	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 $conf
	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 -j8 dtbs
}

#
# Clean the build-directory for an architecture
#
# $1: target arch (arm32, arm64)
#
clean_kernel() {
	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 clean
}

install_setup() {
	if [ ! -d _bootfarm ]; then
		mkdir _bootfarm
	fi

	if [ ! -d _bootfarm/$1 ]; then
		mkdir _bootfarm/$1
	fi
}

#
# Install Kernel and modules for build-directory
# This will copy the kernel, tar up the modules and copy them
# to an architecture-specific directory under _bootfarm.
# If the bootfarm is online, these will also get scp'ed to it.
# The scp operation is conditional on kernel / modules being
# different to what was transferred the last time.
#
# $1: target arch (arm32, arm64)
#
install_kernel() {
	install_setup $1

	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			KERNELIMAGE=zImage
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			KERNELIMAGE=Image
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ -f _bootfarm/$1/$KERNELIMAGE ]; then
		rm _bootfarm/$1/$KERNELIMAGE
	fi

	cp _build-$1/arch/$KERNELARCH/boot/$KERNELIMAGE _bootfarm/$1
	cp _build-$1/include/config/kernel.release _bootfarm/$1

	if [ -d _bootfarm/$1/lib ]; then
		rm -r _bootfarm/$1/lib
	fi

	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 -j8 INSTALL_MOD_PATH=../_bootfarm/$1 modules_install

	if [ -f _bootfarm/$1/modules-$1.tar.gz ]; then
		rm  _bootfarm/$1/modules-$1.tar.gz
	fi

	tar -C _bootfarm/$1/lib/modules -czf _bootfarm/$1/modules-$1.tar.gz .

	if [ -d _bootfarm/$1/lib ]; then
		rm -r _bootfarm/$1/lib
	fi

	set +e
	ping -c 1 $bootfarmip >/dev/null
	err=$?
	set -e
	if [ "x$err" != "x0" ]; then
		echo "skipping bootfarm copy"
	else
		skip=no

		if [ -f _bootfarm/$1/$KERNELIMAGE.bootfarm ]; then
			set +e
			diff _bootfarm/$1/$KERNELIMAGE _bootfarm/$1/$KERNELIMAGE.bootfarm
			err=$?
			set -e
			if [ "x$err" = "x0" ]; then
				echo "kernel identical"
				skip=yes
			fi
		fi

		# copy kernel to bootfarm and keep a copy for future diffing
		if [ "$skip" = "no" ]; then
			scp -C _bootfarm/$1/$KERNELIMAGE $bootfarmip:/home/devel/nfs/kernel/$1
			scp -C _bootfarm/$1/kernel.release $bootfarmip:/home/devel/nfs/kernel/$1
			cp _bootfarm/$1/$KERNELIMAGE _bootfarm/$1/$KERNELIMAGE.bootfarm
		fi

		skip=no
		if [ -f _bootfarm/$1/modules-$1.tar.gz.bootfarm ]; then
			sum1=`tar -xOzf _bootfarm/$1/modules-$1.tar.gz.bootfarm  | sha1sum`
			sum2=`tar -xOzf _bootfarm/$1/modules-$1.tar.gz  | sha1sum`

			if [ "$sum1" = "$sum2" ]; then
				echo "modules identical"
				skip=yes
			fi
		fi

		# copy modules to bootfarm and keep a copy for future diffing
		if [ "$skip" = "no" ]; then
			scp -C _bootfarm/$1/modules-$1.tar.gz $bootfarmip:/home/devel/nfs/kernel/$1
			cp _bootfarm/$1/modules-$1.tar.gz _bootfarm/$1/modules-$1.tar.gz.bootfarm
		fi
	fi
}

#
# Install built dtbs files
# Similar to install_kernel the tar'ed dtbs will also get copied
# to the bootfarm if it is online and the dtbs contents changed.
#
# $1: architecture
# $2: list of patterns to match against without asterisks
# example: install_dtbs arm64 "rk msm89"
# 
install_dtbs() {
	install_setup $1

	case "$1" in
		arm32)
			KERNELARCH=arm
			SUBDIR=""
			;;
		arm64)
			KERNELARCH=arm64
			SUBDIR="*/"
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	pattern=""
	for i in $2; do
		pattern="$pattern _build-$1/arch/$KERNELARCH/boot/dts/$SUBDIR$i*"
	done

	if [ -f _bootfarm/$1/dtbs-$1.tar.gz ]; then
		rm _bootfarm/$1/dtbs-$1.tar.gz
	fi

	mkdir _bootfarm/$1/dtbs
	for i in $pattern; do
		cp $i _bootfarm/$1/dtbs
	done
	tar -C _bootfarm/$1/dtbs -czf _bootfarm/$1/dtbs-$1.tar.gz .
	rm -rf _bootfarm/$1/dtbs

	set +e
	ping -c 1 $bootfarmip >/dev/null
	err=$?
	set -e
	if [ "x$err" != "x0" ]; then
		echo "skipping dtbs copy"
	else
		skip=no
		if [ -f _bootfarm/$1/dtbs-$1.tar.gz.bootfarm ]; then
			sum1=`tar -xOzf _bootfarm/$1/dtbs-$1.tar.gz.bootfarm  | sha1sum`
			sum2=`tar -xOzf _bootfarm/$1/dtbs-$1.tar.gz  | sha1sum`

			if [ "$sum1" = "$sum2" ]; then
				echo "dtbs identical"
				skip=yes
			fi
		fi

		# copy dtbs to bootfarm and keep a copy for future diffing
		if [ "$skip" = "no" ]; then
			scp -C _bootfarm/$1/dtbs-$1.tar.gz $bootfarmip:/home/devel/nfs/kernel/$1
			cp _bootfarm/$1/dtbs-$1.tar.gz _bootfarm/$1/dtbs-$1.tar.gz.bootfarm
		fi
	fi
}

#
# Trigger a rebuild of the netboot images of bootfarm devices
# This will not only create the kernel netboot images (FIT or ChromeOS
# in mose cases) but also distribute the modules to the nfsroot
# instances listed on the bootfarm
#
trigger_bootfarm() {
	if [ $# = "1" ]; then
		ARCH=$1
	else
		ARCH="*"
	fi
	set +e
	ping -c 1 $bootfarmip >/dev/null
	err=$?
	set -e
	if [ "x$err" != "x0" ]; then
		echo "bootfarm not online - not refreshing"
	else
		ssh $bootfarmip "/home/devel/hstuebner/bootfarm/server/rebuild-netboot.sh $ARCH"
	fi
}

setup_modules() {
	local ARCH=$1
	local INST=$2
	local TARGET=$3

	if [ -d $TARGET/lib/modules ]; then
		set +e
		rm -rf $TARGET/lib/modules/*
		set -e
	else
		sudo mkdir $TARGET/lib/modules
		sudo chown hstuebner.hstuebner $TARGET/lib/modules
	fi
}

unpack_modules() {
	local ARCH=$1
	local INST=$2
	local TARGET=$3

	if [ -d /home/devel/nfs/kernel/$INST ]; then
		echo "$INST: unpacking special modules"
		tar -C $TARGET/lib/modules -xzf /home/devel/nfs/kernel/$INST/modules-$INST.tar.gz
	else
		echo "$INST: unpacking $ARCH modules"
		tar -C $TARGET/lib/modules -xzf /home/devel/nfs/kernel/$ARCH/modules-$ARCH.tar.gz
	fi
}

#
# Setup data for the local image generation.
# This includes getting the kernel image from the build directory
# and extracting the dtbs again from their build-archive.
#
# $1: architecture
#
setup_imagedata() {
	ARCH=$1

	case "$ARCH" in
		arm32)
			KERNELIMAGE=zImage
			;;
		arm64)
			KERNELIMAGE=Image
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	cp _bootfarm/$ARCH/kernel.release /home/devel/nfs/kernel/$ARCH
	cp _bootfarm/$ARCH/$KERNELIMAGE _bootfarm/images/$ARCH
	cp _bootfarm/$ARCH/modules-$ARCH.tar.gz /home/devel/nfs/kernel/$ARCH
	tar -C _bootfarm/images/$ARCH/dtbs -xzf _bootfarm/$ARCH/dtbs-$ARCH.tar.gz

	if [ -d /home/devel/nfs/rootfs-$ARCH-base ]; then
		setup_modules $ARCH $ARCH-base /home/devel/nfs/rootfs-$ARCH-base
		unpack_modules $ARCH $ARCH-base /home/devel/nfs/rootfs-$ARCH-base
	fi
}

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

#
# Generates a coreboot partition image for ChromeOS devices.
#
# $1: image name
# $2: architecture (arm32, arm64)
#
generate_chromeos_image() {
	mkimage -D "-q" -f _bootfarm/images/$1-kernel.its _bootfarm/images/tmp/$1-vmlinux.uimg > /dev/null

	vbutil_kernel --pack _bootfarm/images/out/$1-vmlinux.kpart \
	              --version 1 \
	              --vmlinuz _bootfarm/images/tmp/$1-vmlinux.uimg \
	              --arch arm \
	              --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	              --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
	              --bootloader _bootfarm/images/boot.scr.uimg \
	              --config _bootfarm/images/$1-cmdline

	rm _bootfarm/images/tmp/$1-vmlinux.uimg
}

#
# Generates a legacy image for Rockchip devices.
# This means concatenating the dtb to the kernel and running rkcrc on it.
# FIXME: Legacy arm64 images might need more work, as they use separate
# devicetrees already, albeit in some different storage form.
#
# $1: image name
# $2: architecture (arm32, arm64)
#
generate_legacy_image() {
	INST=$1
	ARCH=$2

	case "$ARCH" in
		arm32)
			KERNELIMAGE=zImage
			;;
		arm64)
			KERNELIMAGE=Image
			;;
		*)
			echo "unsupported architecture $ARCH"
			exit 1
			;;
	esac

	DTB=`find _bootfarm/images/arm32/dtbs/ | grep $INST | grep dtb` || exit 1

	cat _bootfarm/images/$ARCH/$KERNELIMAGE $DTB > _bootfarm/images/tmp/$INST.krnl
	rkcrc -k _bootfarm/images/tmp/$INST.krnl _bootfarm/images/out/$INST-legacy.img
	rm _bootfarm/images/tmp/$INST.krnl
}

generate_legacy64_image() {
	INST=$1
	ARCH=$2

	KERNELIMAGE=Image
	DTB=`find _bootfarm/images/arm64/dtbs/ | grep $INST | grep dtb` || exit 1

	_bootfarm/bin/resource_tool --pack --image=_bootfarm/images/out/$INST-resource.img $DTB
	rkcrc -k _bootfarm/images/$ARCH/$KERNELIMAGE _bootfarm/images/out/$INST-kernel.img
}

#
# Generate all images from the image list
# Essentially just calls the correct image generation function.
#
generate_images() {
	for i in `cat _bootfarm/images/instances | grep -v "^#"`; do
		ARCH=`echo $i | cut -d ":" -f 2`
		INST=`echo $i | cut -d ":" -f 1`
		LDR=`echo $i | cut -d ":" -f 3`

		echo "building local $LDR-image for $INST"

		generate_${LDR}_image $INST $ARCH
	done
}
