#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot arm64 $1
	install_uboot arm64 $1
elif [ -d bl31 ]; then
	# we're building tf-a
	build_atf arm64 $1
	install_atf arm64 $1
elif [ -d core/tee ]; then
	# we're building OP-Tee
	build_optee arm64 $1
	install_optee arm64 $1
else
	# assume building a linux-kernel
	build_kernel arm64 $1
	install_kernel arm64
	install_dtbs arm64 "rk px30"

	trigger_bootfarm arm64
fi
