#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot riscv $1
	install_uboot riscv $1
else
	# assume building a linux-kernel
	build_kernel riscv $1
	install_kernel riscv
	install_dtbs riscv ""

	trigger_bootfarm riscv
fi
