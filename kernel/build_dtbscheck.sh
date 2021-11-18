#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

if [ "x$1" = "x" ]; then
	target="all"
else
	target=$1
fi

for arch in arm32 arm64; do
	if [ "$target" != "all" ] && [ "$arch" != "$target" ]; then
		echo "skipping $arch, not target $target"
		continue
	fi

	build_dtbscheck $arch
done
