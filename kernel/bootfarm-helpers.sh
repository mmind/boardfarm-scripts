
bootfarmip=192.168.140.1

# supported atf platforms
atf32="rk3288"
atf64="px30 rk3328 rk3368 rk3399"

# supported optee platforms
optee32="rk322x"
optee64="px30 rk3399"

# supported socs for uboot architecture selection for mkimage
socs="rk3036 rk3066a rk3188 $atf32 $atf64"

# Create icecc compiler package via
# /usr/bin/icecc-create-env --gcc <gcc_path>
create_icecc_env() {
	HOSTARCH=`uname -m`

# newer icecc versions seem to be able to handle this automatically now?
# FIXME: double-check
#	case "$HOSTARCH" in
#		x86_64)
#			ICECC_VERSION=`pwd`/__maintainer-scripts/toolchains/gcc11-amd64-amd64.tar.gz=x86_64-linux-gnu
#			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc11-amd64-armhf.tar.gz=arm-linux-gnueabihf
#			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc11-amd64-aarch64.tar.gz=aarch64-linux-gnu
#			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc11-amd64-riscv64.tar.gz=riscv64-linux-gnu
#			;;
#		aarch64)
#			ICECC_VERSION=`pwd`/__maintainer-scripts/toolchains/gcc10-aarch64.tar.gz
#			ICECC_VERSION=$ICECC_VERSION,`pwd`/__maintainer-scripts/toolchains/gcc10-armhf.tar.gz=arm-linux-gnueabihf
#			;;
#		*)
#			echo "unsupported host architecture $HOSTARCH"
#			exit 1
#			;;
#	esac
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
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			IMAGE=Image
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
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

	if [ -d /usr/lib/icecc ] && [ -f __maintainer-scripts/toolchains/gcc11-amd64-amd64.tar.gz ]; then
		echo "using icecc"
		export PATH=/usr/lib/icecc/bin:$PATH
	fi

	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS KCPPFLAGS="-fno-pic -Wno-pointer-sign" O=_build-$1 $conf
	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS KCPPFLAGS="-fno-pic -Wno-pointer-sign" O=_build-$1 -j14 $IMAGE

	set +e
	cat _build-$1/.config | grep "CONFIG_MODULES=y" > /dev/null
	ret=$?
	set -e
	if [ "x$ret" = "x0" ]; then
		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS KCPPFLAGS="-fno-pic -Wno-pointer-sign" O=_build-$1 -j14 modules
	fi

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
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
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
# Check devicetree YAML for an architecture
#
# $1: target arch (arm32, arm64)
# $2: config to build (default oldconfig)
#
build_dtbscheck() {
	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			;;
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
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
	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 -j8 dt_binding_check
	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 -j8 dtbs_check
}

# Find out the soc uboot was built for
# For this grep the uboot config for the matching CONFIG_ROCKCHIP_$soc
# config variable.
#
# $1: target arch (arm32, arm64)
# $2: target build
#
find_uboot_soc() {
	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			;;
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	for i in $socs; do
		set +e
		cat _build-$1/$2/u-boot.cfg | cut -d " " -f 2 | grep -i CONFIG_ROCKCHIP_$i > /dev/null
		ret=$?
		set -e
		if [ "x$ret" = "x0" ]; then
			echo $i
			return
		fi
	done
}

# Determine if the uboot build will require ATF
# Missing the blXY.elf can lead to "interesting" results like
# the gmac spontanously not working as uboot will create a
# dummy blXY.elf in that case.
#
# $1: target arch (arm32, arm64)
# $2: target build
#
find_uboot_isatf() {
	set +e
	cat _build-$1/$2/u-boot.cfg | cut -d " " -f 2 | grep -i CONFIG_SPL_ATF > /dev/null
	ret=$?
	set -e
	if [ "x$ret" = "x0" ]; then
		echo "atf"
		return
	fi
}

#
# Build u-boot for a target
# Cross-compilers are hardcoded for the standard packaged
# cross-compilers on a Debian system
#
# $1: target arch (arm32, arm64)
# $2: config to build (optional, default all)
#
build_uboot() {
	create_icecc_env
	export ICECC_VERSION

	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			BL=bl32
			;;
		arm64)
			KERNELARCH=arm
			CROSS=aarch64-linux-gnu-
			BL=bl31
			;;
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ -d /usr/lib/icecc ] && [ -f __maintainer-scripts/toolchains/gcc11-amd64-amd64.tar.gz ]; then
		echo "using icecc"
		export PATH=/usr/lib/icecc/bin:$PATH
	fi

	if [ ! -d _build-$1 ]; then
		mkdir _build-$1
	fi

	if [ "x$2" = "x" ]; then
		conf="*"
		if [ ! -f _build-$1/builds ]; then
			echo "$1: no builds registered"
			return
		fi
	else
		set +e
		cat _build-$1/builds | grep $2 > /dev/null
		ret=$?
		set -e
		if [ "x$ret" != "x0" ]; then
			# make sure we have a defconfig, before adding the build
			if [ ! -f configs/$2_defconfig ]; then
				echo "$2: no defconfig found for new build"
				exit 1
			fi

			echo $2 >> _build-$1/builds
		fi

		conf=$2
	fi

	for c in `cat _build-$1/builds | grep -v "^#"`; do
		if [ "$conf" != "*" ] && [ "$conf" != "$c" ]; then
			echo "$c: skipping build"
			continue
		fi

		set +e
# if we want to use make clean, we'll need to copy the bl31.elf into the builddir
# after make defconfig
#		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1/$c clean
#		ret=$?
#		if [ "x$ret" != "x0" ]; then
#			continue
#		fi

		# make the boards defconfig - this also creates the build dir
		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1/$c ${c}_defconfig
		ret=$?
		if [ "x$ret" != "x0" ]; then
			continue
		fi

		# if needed check for the presence of the ATF binary
		needsatf=$(find_uboot_isatf $1 $c)
		if [ "$needsatf" = "atf" ] && [ ! -f _build-$1/$c/$BL.elf ]; then
			echo "$c: missing $BL.elf"
			exit 1
		fi

		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1/$c -j14
		ret=$?
		if [ "x$ret" != "x0" ]; then
			continue
		fi

		# riscv64 doesn't use a u-boot fit image, but instead encapsulates
		# the u-boot binary into a opensbi firmware image
		if [ "$1" = "riscv32" ] || [ "$1" = "riscv64" ]; then
			continue
		fi

		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1/$c -j14 u-boot.itb
		ret=$?
		if [ "x$ret" != "x0" ]; then
			continue
		fi

		set -e
	done
}

#
# Build atf for a target
# Cross-compilers are hardcoded for the standard packaged
# cross-compilers on a Debian system
#
# $1: target arch (arm32, arm64)
# $2: platform to build (optional, default all)
#
build_atf() {
	create_icecc_env
	export ICECC_VERSION

	case "$1" in
		arm32)
			KERNELARCH=aarch32
			CROSS="arm-linux-gnueabihf- AARCH32_SP=sp_min"
			PLATS="$atf32"
			BL=bl32
			;;
		arm64)
			KERNELARCH=aarch64
			CROSS=aarch64-linux-gnu-
			PLATS="$atf64"
			BL="SPD=opteed bl31"
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="*"
	else
		conf=$2
	fi

	if [ -d /usr/lib/icecc ] && [ -f __maintainer-scripts/toolchains/gcc11-amd64-amd64.tar.gz ]; then
		echo "using icecc"
		export PATH=/usr/lib/icecc/bin:$PATH
	fi

	for p in $PLATS; do
		if [ "$conf" != "*" ] && [ "$conf" != "$p" ]; then
			echo "$p: skipping build"
			continue
		fi

		echo "$p: building atf with $BL"
		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS PLAT=$p clean > /dev/null
		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS PLAT=$p -j14 $BL > /dev/null
	done
}

#
# Build opensbi-binaries
#
# $1: architecture
# $2: board
# $3: opensbi-platform - default generic
# $4: fw_payload_path
# $5: fw_fdt_path
#
build_opensbi() {
	create_icecc_env
	export ICECC_VERSION

	case "$1" in
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			XLEN=32
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			XLEN=64
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ -d /usr/lib/icecc ] && [ -f __maintainer-scripts/toolchains/gcc11-amd64-amd64.tar.gz ]; then
		echo "using icecc"
		export PATH=/usr/lib/icecc/bin:$PATH
	fi

	if [ ! -d _build-$1 ]; then
		mkdir _build-$1
	fi

	if [ "x$3" = "x" ]; then
		plat=generic
		flag=""
	else
		plat=`echo $3 | cut -d "-" -f 1`
		flag=`echo $3 | cut -d "-" -f 2`
	fi

	if [ "$flag" = "pic" ]; then
		fw_pic=" FW_PIC=y"
	fi

	if [ "x$4" != "x" ]; then
		fw_payload=" FW_PAYLOAD_PATH=$4"
	fi

	if [ "x$5" != "x" ]; then
		fw_fdt=" FW_FDT_PATH=$5"
	fi

	make CROSS_COMPILE=${CROSS} ARCH=riscv PLATFORM_RISCV_XLEN=${XLEN} PLATFORM=${plat} ${fw_payload}${fw_fdt}${fw_pic} O=_build-$1/$2
}

#
# Build optee for a target
# Cross-compilers are hardcoded for the standard packaged
# cross-compilers on a Debian system
#
# $1: target arch (arm32, arm64)
# $2: platform to build (optional, default all)
#
build_optee() {
	create_icecc_env
	export ICECC_VERSION

	case "$1" in
		arm32)
			KERNELARCH=aarch32
			CROSS="CROSS_COMPILE32=arm-linux-gnueabihf-"
			PLATS="$optee32"
			;;
		arm64)
			KERNELARCH=aarch64
			CROSS="CROSS_COMPILE32=arm-linux-gnueabihf- CROSS_COMPILE64=aarch64-linux-gnu-"
			PLATS="$optee64"
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="*"
	else
		conf=$2
	fi

	if [ -d /usr/lib/icecc ] && [ -f __maintainer-scripts/toolchains/gcc11-amd64-amd64.tar.gz ]; then
		echo "using icecc"
		export PATH=/usr/lib/icecc/bin:$PATH
	fi

	for p in $PLATS; do
		if [ "$conf" != "*" ] && [ "$conf" != "$p" ]; then
			echo "$p: skipping build"
			continue
		fi

		echo "$p: building optee"
		make $CROSS CFG_WERROR=y PLATFORM=rockchip PLATFORM_FLAVOR=$p O=_build-$1/$p -j14 all > /dev/null
	done
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
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 clean
}

#
# Clean the build-directory for an optee-platform
#
# $1: target arch (arm32, arm64)
# $2: optional platform specifier to limit actions to it
#
clean_optee() {
	case "$1" in
		arm32)
			KERNELARCH=aarch32
			CROSS="CROSS_COMPILE32=arm-linux-gnueabihf-"
			PLATS="$optee32"
			;;
		arm64)
			KERNELARCH=aarch64
			CROSS="CROSS_COMPILE32=arm-linux-gnueabihf- CROSS_COMPILE64=aarch64-linux-gnu-"
			PLATS="$optee64"
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="*"
	else
		conf=$2
	fi

	for p in $PLATS; do
		if [ "$conf" != "*" ] && [ "$conf" != "$p" ]; then
			echo "$p: skipping build"
			continue
		fi

		make $CROSS CFG_WERROR=y PLATFORM=rockchip PLATFORM_FLAVOR=$p O=_build-$1/$p clean
	done
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
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			KERNELIMAGE=Image
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
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

	set +e
	cat _build-$1/.config | grep "CONFIG_MODULES=y" > /dev/null
	ret=$?
	set -e
	if [ "x$ret" = "x0" ]; then
		make ARCH=$KERNELARCH CROSS_COMPILE=$CROSS O=_build-$1 -j8 INSTALL_MOD_PATH=../_bootfarm/$1 modules_install
	else
		rel=`cat _build-$1/include/config/kernel.release`
		mkdir -p _bootfarm/$1/lib/modules/$rel
		touch _bootfarm/$1/lib/modules/$rel/no-modules
	fi

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
		riscv32)
			# needs gcc-riscv32-linux-gnu
			KERNELARCH=riscv
			SUBDIR="*/"
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
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

	if [ -d _bootfarm/$1/dtbs ]; then
		rm -rf _bootfarm/$1/dtbs
	fi

	mkdir _bootfarm/$1/dtbs

	set +e
	for i in $pattern; do
		cp $i _bootfarm/$1/dtbs 2>/dev/null
	done
	set -e

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

install_opensbi() {
	install_setup $1

	case "$1" in
		riscv32)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv32
			CROSS=riscv64-linux-gnu-
			XLEN=32
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv64
			CROSS=riscv64-linux-gnu-
			XLEN=64
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ ! -d _bootfarm/$2 ]; then
		mkdir _bootfarm/$2
	fi

	if [ "x$3" = "x" ]; then
		plat=generic
		flag=""
	else
		plat=`echo $3 | cut -d "-" -f 1`
		flag=`echo $3 | cut -d "-" -f 2`
	fi

	cp _build-$1/$2/platform/${plat}/firmware/fw_dynamic.bin _bootfarm/$2/opensbi-${KERNELARCH}-${plat}-fw_dynamic.bin
	cp _build-$1/$2/platform/${plat}/firmware/fw_dynamic.elf _bootfarm/$2/opensbi-${KERNELARCH}-${plat}-fw_dynamic.elf
}

install_uboot_rockchip() {
	plat=$(find_uboot_soc $1 $2)
	echo "Platform $plat"

	if [ ! -d _bootfarm/$2 ]; then
		mkdir _bootfarm/$2
	fi

	if [ ! -f _build-$1/$2/spl/u-boot-spl.bin ]; then
		echo "$2: build seems incomplete, skipping"
		return
	fi

	# create sd-card images
	if [ -d "_build-$1/$2/tpl" ]; then
		# tpl + spl combined
		_build-$1/$2/tools/mkimage -n $plat -T rksd -d _build-$1/$2/tpl/u-boot-tpl.bin _bootfarm/$2/spl_mmc.img
		cat _build-$1/$2/spl/u-boot-spl-dtb.bin >> _bootfarm/$2/spl_mmc.img
	else
		# spl-only image
		_build-$1/$2/tools/mkimage -n $plat -T rksd -d _build-$1/$2/spl/u-boot-spl.bin _bootfarm/$2/spl_mmc.img
	fi
	cp _build-$1/$2/u-boot.itb _bootfarm/$2

	# read raw offset to load the u-boot binary from and create a
	# flash script to write both parts (spl/tpl+spl and uboot iself)
	# to a sd-card
	sd_offs=`cat _build-$1/$2/u-boot.cfg | grep CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_SECTOR | cut -d " " -f 3`
	cat <<EOF > _bootfarm/$c/flash_sd.sh
#!/bin/sh

if [ "x\$1" = "x" ]; then
	echo "Usage: flash_sd.sh target_device"
	exit 1
fi

if [ ! -b \$1 ]; then
	echo "target is not a block device"
	exit 1
fi

dd if=spl_mmc.img of=\$1 seek=64
dd if=u-boot.itb of=\$1 seek=$(($sd_offs))
sync

EOF

	chmod +x _bootfarm/$2/flash_sd.sh
}

#
# Check and prepare opensbi installation
#
# A number of RiscV board incorprorate the opensbi into their
# build process and we want to access that target source through
# a symlink. Check its existence and if needed create the opensbi
# build directory.
#
prepare_opensbi() {
	if [ ! -d _bootfarm/$2/opensbi ] && [ ! -h _bootfarm/$2/opensbi ]; then
		echo ""
		echo "Build aborted"
		echo "-------------"
		echo ""
		echo "Please make your target opensbi available as _bootfarm/$2/opensbi"
		echo "This can either be a subdirectory containing the sources,"
		echo "or a symlink pointing to the target opensbi sources."
		exit 1
	fi

	if [ ! -d _bootfarm/$2/opensbi/_build-$1 ]; then
		mkdir _bootfarm/$2/opensbi/_build-$1
	fi
}

install_uboot_beaglev() {
	if [ ! -d _bootfarm/$2 ]; then
		mkdir _bootfarm/$2
	fi

	prepare_opensbi $1 $2
	U_BOOT_PATH=`pwd`/_bootfarm/$2

	cd _bootfarm/$2/opensbi
	build_opensbi $1 $2 generic ${U_BOOT_PATH}/u-boot.bin FW_FDT_PATH=${U_BOOT_PATH}/u-boot.dtb
	cd ../../..

	cp _build-$1/$2/u-boot.bin _bootfarm/$2
	cp _build-$1/$2/u-boot.dtb _bootfarm/$2
	cp _bootfarm/$2/opensbi/_build-$1/$2/platform/generic/firmware/fw_payload.bin _bootfarm/$2

	inFile=_bootfarm/$2/fw_payload.bin
	outFile=$inFile.out

	inSize=`stat -c "%s" $inFile`
	inSize32HexBe=`printf "%08x\n" $inSize`
	inSize32HexLe=${inSize32HexBe:6:2}${inSize32HexBe:4:2}${inSize32HexBe:2:2}${inSize32HexBe:0:2}

	echo $inSize32HexLe | xxd -r -ps > $outFile
	cat $inFile >> $outFile

	outSize=`stat -c "%s" $outFile`
	outSize32HexBe=`printf "%08x\n" $outSize`

	echo "Build finished"
	echo "--------------"
	echo ""
	echo "Flash instructions:"
	echo ""
	echo "Start serial console as"
	echo "    picocom -b 115200 -s "sx -vv" /dev/ttyUSB0"
	echo ""
	echo "Start board and press a key on the keyloaders countdown"
	echo ""
	echo "Press 0 + Enter, wait for the C character being displayed."
	echo "Press [Ctrl][a] [Ctrl][s]. Picocom will then ask for a file name,"
	echo "and you should type"
	echo "    _bootfarm/$2/fw_payload.bin.out"
}

# Icicle board firmware build
# We don't want the openSBI included in the hart-software-services, but instead
# use our own (likely newer) sbi for testing.
# Hence using the "custom" boot-flow for the hss parts.
install_uboot_icicle() {
	if [ ! -d _bootfarm/$2 ]; then
		mkdir _bootfarm/$2
	fi

	prepare_opensbi $1 $2
	U_BOOT_PATH=`pwd`/_bootfarm/$2

	cd _bootfarm/$2/opensbi
	build_opensbi $1 $2 generic ${U_BOOT_PATH}/u-boot.bin FW_FDT_PATH=${U_BOOT_PATH}/u-boot.dtb
	cd ../../..

	cp _build-$1/$2/u-boot.bin _bootfarm/$2
	cp _build-$1/$2/u-boot.dtb _bootfarm/$2
	cp _build-$1/$2/u-boot-dtb.bin _bootfarm/$2
	cp _bootfarm/$2/opensbi/_build-$1/$2/platform/generic/firmware/fw_payload.bin _bootfarm/$2

	if [ ! -d _bootfarm/$2/hss ] && [ ! -h _bootfarm/$2/hss ]; then
		echo ""
		echo "Build aborted"
		echo "-------------"
		echo ""
		echo "Please make your target Microchip HSS available as _bootfarm/$2/hss"
		echo "This can either be a subdirectory containing the sources,"
		echo "or a symlink pointing to the target opensbi sources."
		exit 1
	fi

	cd _bootfarm/$2/hss
	cp boards/mpfs-icicle-kit-es/def_config_custom .config
	make CROSS_COMPILE=riscv64-linux-gnu- BOARD=mpfs-icicle-kit-es
	cd tools/hss-payload-generator
	make
	cd ../..
	cd ../../..

	cat << EO2 > _bootfarm/$2/hss-payload.yaml
set-name: 'PolarFire-SoC-HSS::U-Boot-local'
hart-entry-points: {u54_1: '0x80000000', u54_2: '0x80000000', u54_3: '0x80000000', u54_4: '0x80000000'}
payloads:
   $U_BOOT_PATH/fw_payload.bin: {exec-addr: '0x80000000', owner-hart: u54_1, secondary-hart: u54_2, secondary-hart: u54_3, secondary-hart: u54_4, priv-mode: prv_m}

EO2
	_bootfarm/$2/hss/tools/hss-payload-generator/hss-payload-generator -c $U_BOOT_PATH/hss-payload.yaml $U_BOOT_PATH/hss-payload.bin

	echo ""
	echo "Build finished"
	echo "--------------"
	echo ""
	echo "now poweron the device, stop the hss boot and run the"
	echo ""
	echo "    'usbdmsc'"
	echo ""
	echo "command to expose the emmc as usb mass storage device"
	echo "via the OTG port."
	echo ""
	echo "Once that is available on the host, change back to the"
	echo "u-boot directory and do"
	echo ""
	echo "    dd if=_bootfarm/hss-payload.bin of=/dev/sdb2 bs=512"
	echo ""
	echo "Make sure that it's the correct drive ;-)"
	echo ""
}

install_uboot_nezha() {
	if [ ! -d _bootfarm/$2 ]; then
		mkdir _bootfarm/$2
	fi

	prepare_opensbi $1 $2

	cd _bootfarm/$2/opensbi
	build_opensbi $1 $2 generic-pic
	cd ../../..

	cp _build-$1/$2/u-boot-nodtb.bin _bootfarm/$2
	cp _build-$1/$2/arch/riscv/dts/sun20i-d1-nezha.dtb _bootfarm/$2
	cp _bootfarm/$2/opensbi/_build-$1/$2/platform/generic/firmware/fw_dynamic.bin _bootfarm/$2

	cat << EOF > _bootfarm/$2/toc1.cfg
[opensbi]
file = _bootfarm/$2/fw_dynamic.bin
addr = 0x40000000
[dtb]
file = _bootfarm/$2/sun20i-d1-nezha.dtb
addr = 0x44000000
[u-boot]
file = _bootfarm/$2/u-boot-nodtb.bin
addr = 0x4a000000
EOF

	_build-$1/$2/tools/mkimage -T sunxi_toc1 -d _bootfarm/$2/toc1.cfg _bootfarm/$2/u-boot.toc1

	cat <<EOF > _bootfarm/$2/flash_sd.sh
#!/bin/sh

if [ "x\$1" = "x" ]; then
	echo "Usage: flash_sd.sh target_device"
	exit 1
fi

if [ ! -b \$1 ]; then
	echo "target is not a block device"
	exit 1
fi

dd if=u-boot.toc1 of=\$1 bs=512 seek=32800
sync

EOF
	chmod +x _bootfarm/$2/flash_sd.sh

	echo ""
	echo "Build finished"
	echo "--------------"
	echo ""
	echo "You can now use the flash_sd.sh script to write the image to an sd-card"
	echo "Make sure the separate boot0 image is also present on the card"
}

install_uboot_riscv64() {
	case "$2" in
		microchip_mpfs_icicle)
			install_uboot_icicle $1 $2
			;;
		starfive_jh7100_starlight_smode)
			install_uboot_beaglev $1 $2
			;;
		nezha)
			install_uboot_nezha $1 $2
			;;
		*)
			echo ""
			echo "Build finished"
			echo "--------------"
			echo ""
			echo "No firmware build-instructions for board $2"
			;;
	esac
}

#
# Install u-boot (= create images to flash to a device)
# This will walk through the selected builds for an arch
# or just process the specific one and create a tpl/spl image
# in a target directory, copy the u-boot.itb there and create
# a flash-script for sd-cards, based on the raw-sectors
# deduced from the u-boot config it was build from.
#
# $1: target arch (arm32, arm64)
# $2: target build (optional, default all)
#
install_uboot() {
	install_setup $1

	case "$1" in
		arm32)
			KERNELARCH=arm
			CROSS=arm-linux-gnueabihf-
			;;
		arm64)
			KERNELARCH=arm64
			CROSS=aarch64-linux-gnu-
			;;
		riscv32)
			# needs gcc-riscv32-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		riscv64)
			# needs gcc-riscv64-linux-gnu
			KERNELARCH=riscv
			CROSS=riscv64-linux-gnu-
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="*"
	else
		conf=$2
	fi

	for c in `cat _build-$1/builds | grep -v "^#"`; do
		if [ "$conf" != "*" ] && [ "$conf" != "$c" ]; then
			echo "$c: skipping build"
			continue
		fi

		if [ "$1" = "riscv64" ]; then
			install_uboot_riscv64 $1 $c
		else
			install_uboot_rockchip $1 $c
		fi
	done

	# create a frankenstein image with binary-loader as tpl and spl
	# for rkdeveloptool
#	_bootfarm/boot_merger _bootfarm/px30.ini
#	scp -C _bootfarm/loader.bin 192.168.137.170:/tmp
}

#
# Install atf binary for a target
# This means copying the created binary to a standard location
#
# $1: target arch (arm32, arm64)
# $2: platform to build (optional, default all)
#
install_atf() {
	install_setup $1

	case "$1" in
		arm32)
			KERNELARCH=aarch32
			CROSS="arm-linux-gnueabihf- AARCH32_SP=sp_min"
			PLATS="$atf32"
			BL=bl32
			;;
		arm64)
			KERNELARCH=aarch64
			CROSS=aarch64-linux-gnu-
			PLATS="$atf64"
			BL=bl31
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="*"
	else
		conf=$2
	fi

	for p in $PLATS; do
		if [ "$conf" != "*" ] && [ "$conf" != "$p" ]; then
			echo "$p: skipping build"
			continue
		fi

		echo "$p: installing atf"

		if [ ! -d _bootfarm/$p ]; then
			mkdir _bootfarm/$p
		fi

		if [ ! -f build/$p/release/$BL/$BL.elf ]; then
			echo "$p: build seems incomplete, skipping"
			continue
		fi

		cp build/$p/release/$BL/$BL.elf _bootfarm/$p
	done
}

#
# Install optee binary for a target
# This means copying the created binary to a standard location
#
# $1: target arch (arm32, arm64)
# $2: platform to build (optional, default all)
#
install_optee() {
	install_setup $1

	case "$1" in
		arm32)
			KERNELARCH=aarch32
			CROSS="arm-linux-gnueabihf-"
			PLATS="$optee32"
			;;
		arm64)
			KERNELARCH=aarch64
			CROSS=aarch64-linux-gnu-
			PLATS="$optee64"
			;;
		*)
			echo "unsupported architecture $1"
			exit 1
			;;
	esac

	if [ "x$2" = "x" ]; then
		conf="*"
	else
		conf=$2
	fi

	for p in $PLATS; do
		if [ "$conf" != "*" ] && [ "$conf" != "$p" ]; then
			echo "$p: skipping build"
			continue
		fi

		echo "$p: installing optee"

		if [ ! -d _bootfarm/$p ]; then
			mkdir _bootfarm/$p
		fi

		if [ ! -f _build-$1/$p/core/tee.elf ]; then
			echo "$p: build seems incomplete, skipping"
			continue
		fi

		cp _build-$1/$p/core/tee.elf _bootfarm/$p
		tar -C _build-$1/$p -czf _bootfarm/$p/export-ta_arm32.tar.gz export-ta_arm32
		tar -C _build-$1/$p -czf _bootfarm/$p/export-ta_arm64.tar.gz export-ta_arm64
	done
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
		riscv32)
			KERNELIMAGE=Image
			;;
		riscv64)
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
