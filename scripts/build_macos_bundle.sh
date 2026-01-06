#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"  # strict mode + env var defaults

# Install Homebrew packages for build requirements
brew update
brew install qt@5 glib libzip libusb hidapi libftdi pkg-config cmake automake libtool python@3

# Ensure brew’s Qt5 is found by build tools
export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/opt/homebrew/opt/qt@5/lib/pkgconfig"

# Build and install libserialport (for serial drivers)
git clone --depth 1 -b "$LIBSIGROK_REF" https://github.com/sigrokproject/libserialport.git
cd libserialport
./autogen.sh && ./configure --prefix=/usr/local
make -j"$(sysctl -n hw.ncpu)" && sudo make install
cd ..

# Build and install libsigrok
git clone --depth 1 -b "$LIBSIGROK_REF" https://github.com/sigrokproject/libsigrok.git
cd libsigrok
./autogen.sh && ./configure --prefix=/usr/local
make -j"$(sysctl -n hw.ncpu)" && sudo make install
cd ..

# Build and install libsigrokdecode
git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode
./autogen.sh && ./configure --prefix=/usr/local
make -j"$(sysctl -n hw.ncpu)" && sudo make install
cd ..

# Build PulseView (Qt application on macOS)
git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@5 -DCMAKE_INSTALL_PREFIX=AppDir -DCMAKE_BUILD_TYPE=Release ..
make -j"$(sysctl -n hw.ncpu)" && make install

# Find and package the .app bundle
cd AppDir
APP_BUNDLE=$(find . -type d -name "PulseView.app" | head -n 1)
zip -r "../PulseView-macOS-arm64.zip" "$APP_BUNDLE"
cd ..
echo "macOS app bundle packaged: PulseView-macOS-arm64.zip"
