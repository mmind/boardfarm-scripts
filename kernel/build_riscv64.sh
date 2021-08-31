#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot riscv64 $1
	install_uboot riscv64 $1
else
	# assume building a linux-kernel
	build_kernel riscv64 $1
	install_kernel riscv64
	install_dtbs riscv64 ""

	trigger_bootfarm riscv64
fi
