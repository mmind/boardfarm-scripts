#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh


if [ -d common/spl ]; then
	# we're building u-boot
	echo "nothing to do yet"
elif [ -d bl31 ]; then
	# we're building tf-a
	echo "nothing to do yet"
elif [ -d core/tee ]; then
	# we're building OP-Tee
	clean_optee arm32
	clean_optee arm64
else
	# assume building a linux-kernel
	clean_kernel arm32
	clean_kernel arm64
	clean_kernel riscv32
	clean_kernel riscv64
fi
