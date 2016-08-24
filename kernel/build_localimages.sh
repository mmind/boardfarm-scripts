#!/bin/bash -e

. __maintainer-scripts/bootfarm-helpers.sh

setup_imagedata arm32
setup_imagedata arm64
generate_images
