#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ -d common/spl ]; then
	# we're building u-boot
	build_uboot arm32
	install_uboot arm32

	build_uboot arm64
	install_uboot arm64

	build_uboot riscv
	install_uboot riscv
elif [ -d bl31 ]; then
	# we're building tf-a
	build_atf arm32 $1
	build_atf arm64 $1

	install_atf arm32 $1
	install_atf arm64 $1
elif [ -d core/tee ]; then
	# we're building OP-Tee
	build_optee arm32 $1
	build_optee arm64 $1

	install_optee arm32 $1
	install_optee arm64 $1
else
	build_kernel arm32
	build_kernel arm64
	build_kernel riscv

	install_kernel arm32
	install_kernel arm64
	install_kernel riscv

	install_dtbs arm32 "rk"
	install_dtbs arm64 "rk px30"
	install_dtbs riscv ""

	trigger_bootfarm
fi
