#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ "x$1" = "x" ]; then
	target="all"
else
	target=$1
fi

if [ "x$2" = "x" ]; then
	board="all"
else
	board=$2
fi

for arch in arm32 arm64 riscv32 riscv64; do
	if [ "$target" != "all" ] && [ "$arch" != "$target" ]; then
		echo "skipping $arch, not target $target"
		continue
	fi

	build_dtbscheck $arch $board
done
