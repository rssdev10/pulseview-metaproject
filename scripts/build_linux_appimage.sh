#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"  # Load common settings (strict mode, env vars)

# Install build dependencies on Ubuntu for PulseView and its libs
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake pkg-config automake autoconf libtool git \
    qtbase5-dev qttools5-dev-tools libqt5svg5-dev \
    libglib2.0-dev libzip-dev libusb-1.0-0-dev libftdi1-dev libhidapi-dev libbluetooth-dev \
    libserialport-dev python3-dev

# Build and install libsigrok (C library)
git clone --depth 1 -b "$LIBSIGROK_REF" https://github.com/sigrokproject/libsigrok.git
cd libsigrok
./autogen.sh && ./configure --prefix=/usr/local
make -j"$(nproc)" 
sudo make install  # Install to /usr/local
cd ..

# Build and install libsigrokdecode (decoder library)
git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode
./autogen.sh && ./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
cd ..

# Build PulseView (Qt application)
git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview
mkdir build && cd build
# Ensure pkg-config can find the newly installed libs
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release ..
make -j"$(nproc)"
sudo make install DESTDIR=AppDir  # Install into AppDir for packaging

# Prepare AppImage using linuxdeploy and its Qt plugin
cd ..
wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
chmod +x linuxdeploy-*.AppImage

# Use linuxdeploy to bundle the AppDir into an AppImage (no Docker, run AppImage directly)
# Note: Do not use ${{ github.* }} expressions in this script; environment is already set:contentReference[oaicite:7]{index=7}.
# Running linuxdeploy (will find the Qt plugin in the same directory)
./linuxdeploy-x86_64.AppImage --appimage-extract-and-run \
    --appdir AppDir \
    --output appimage

# The above produces an AppImage (name includes PulseView and version). Rename it for clarity.
mv PulseView-*-x86_64.AppImage PulseView-x86_64.AppImage 2>/dev/null || mv PulseView*.AppImage PulseView-x86_64.AppImage

echo "Linux AppImage built: $(ls PulseView-x86_64.AppImage)"
