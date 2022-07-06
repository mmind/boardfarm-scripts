#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot riscv64 $1
	install_uboot riscv64 $1
elif [ -d platform/generic ]; then
	# we're building opensbi
	build_opensbi riscv64 dynamic
	install_opensbi riscv64 dynamic
else
	# assume building a linux-kernel
	build_kernel riscv64 $1
	install_kernel riscv64
	install_dtbs riscv64 "jh7100 sun20i-d1 microchip-mpfs-icicle"

	trigger_bootfarm riscv64
fi
