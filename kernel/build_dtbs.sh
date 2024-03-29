#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ "x$1" = "x" ]; then
	target="all"
else
	target=$1
fi

for arch in arm32 arm64 riscv32 riscv64; do
	if [ "$target" != "all" ] && [ "$arch" != "$target" ]; then
		echo "skipping $arch, not target $target"
		continue
	fi

	build_dtbs $arch
	install_dtbs $arch "rk"
done

if [ "$target" != "all" ]; then
    trigger_bootfarm $target
else
    trigger_bootfarm
fi
