#!/bin/bash

export CCACHE_DIR="/ccache"
export CCACHE_NOHASHDIR="1"
export CCACHE_SIZE="1G"
export ZSTD_CLEVEL="1"

CLANG=/clang/bin
export PATH="$CLANG:$PATH"

DIR=$(pwd)

# Install dependencies
pacman -Syu --needed --noconfirm bc ccache cpio curl kmod libelf pahole perl rclone tar unzip xz zip zstd
#apt-get -qq -y update
#apt-get -qq -y install --no-install-recommends ccache rclone tar unzip xz-utils zip zstd

# Setup rclone
mkdir -p ~/.config/rclone
echo "$RCLONE_CONF" > ~/.config/rclone/rclone.conf

# Setup ccache
function setup_ccache() {
	mkdir /ccache
	rclone copy gdrive:ccache-bcm2711.tar.zst /ccache
	tar xf /ccache/ccache-bcm2711.tar.zst -C /ccache
}

# Setup clang
function setup_clang() {
	mkdir /clang
	rclone copy gdrive:clang-r445002.tar.gz /clang
	tar xf /clang/clang-r445002.tar.gz -C /clang
}

# Run in parallel
setup_ccache &
setup_clang &
wait

# Compile kernel
cd "$DIR"
make mrproper
make -j12 bcm2711_defconfig Image dtbs || exit 1

# Pack kernel
function pack_kernel() {
    mkdir -p build/overlays
    cp arch/arm64/boot/Image build/kernel8-kensur.img
    cp arch/arm64/boot/dts/overlays/*.dtb* build/overlays
    cd build
    zip -r9 ../bcm2711_kensur_kernel.zip .
}

# Upload ccache
function upload_ccache() {
    rm /ccache/ccache-bcm2711.tar.zst
    tar --zstd -C /ccache -cf /ccache/ccache-bcm2711.tar.zst ccache
    rclone copy /ccache/ccache-bcm2711.tar.zst gdrive
}

# Run in parallel
pack_kernel &
upload_ccache &
wait

