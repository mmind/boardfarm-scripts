#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

build_kernel arm32 $1
install_kernel arm32
install_dtbs arm32 "rk"

trigger_bootfarm
