#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

setup_imagedata arm32
setup_imagedata arm64
sudo __maintainer-scripts/rebuild-initramfs.sh arm64 arm64-base
generate_images
