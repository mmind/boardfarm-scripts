#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

build_kernel arm32
build_kernel arm64

install_kernel arm32
install_kernel arm64

install_dtbs arm32 "rk"
install_dtbs arm64 "rk"

trigger_bootfarm
