#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

build_kernel arm64 $1
install_kernel arm64
install_dtbs arm64 "rk"

trigger_bootfarm
