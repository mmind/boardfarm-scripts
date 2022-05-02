#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot riscv32 $1
	install_uboot riscv32 $1
else
	# assume building a linux-kernel
	build_kernel riscv32 $1
	install_kernel riscv32
	install_dtbs riscv32 "jh7100 sun20i-d1 microchip-mpfs-icicle"

	trigger_bootfarm riscv32
fi
