#!/bin/bash

# Define the necessary flags for ARM64 architecture
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export MACOSX_DEPLOYMENT_TARGET=$(xcrun --sdk macosx --show-sdk-platform-version)
export CFLAGS="-arch arm64 -isysroot $SDKROOT"
export LDFLAGS="-arch arm64 -isysroot $SDKROOT"
export CC="clang -arch arm64"

# Clone the FFmpeg repository
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
cd ffmpeg

# Configure the build for ARM64 with VideoToolbox support
./configure \
	--prefix=/usr/local \
	--enable-static \
	--disable-shared \
	--disable-everything \
	--disable-xlib \
	--enable-encoder=hevc_videotoolbox,h264_videotoolbox \
	--enable-muxer=mp4 \
	--enable-demuxer=image2pipe \
	--enable-decoder=png \
	--enable-parser=png \
	--enable-protocol=file,pipe,fd \
	--enable-indev=lavfi \
	--enable-filter=scale \
	--enable-bsf=hevc_mp4toannexb \
	--target-os=darwin \
	--arch=arm64

# Compile and install
make clean
make && sudo make install
