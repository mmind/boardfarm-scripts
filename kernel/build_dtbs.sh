#!/bin/sh -e

. __maintainer-scripts/bootfarm-helpers.sh

build_dtbs arm32
build_dtbs arm64

install_dtbs arm32 "rk"
install_dtbs arm64 "rk"
#install_dtbs arm64 "rk msm89"

trigger_bootfarm
