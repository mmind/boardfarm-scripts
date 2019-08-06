#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot arm32 $1
	install_uboot arm32 $1
else
	# assume building a linux-kernel
	build_kernel arm32 $1
	install_kernel arm32
	install_dtbs arm32 "rk"

	trigger_bootfarm arm32
fi
