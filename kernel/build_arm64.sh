#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot arm64 $1
	install_uboot arm64 $1
else
	# assume building a linux-kernel
	build_kernel arm64 $1
	install_kernel arm64
	install_dtbs arm64 "rk"

	trigger_bootfarm arm64
fi
