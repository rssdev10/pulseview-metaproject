#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"  # Load common settings (strict mode, env vars)

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) APPIMAGE_ARCH="x86_64" ;;
    aarch64) APPIMAGE_ARCH="aarch64" ;;
    *) log "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

log "Building Linux AppImage for $APPIMAGE_ARCH"

# Check if running in container (no sudo)
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Install build dependencies on Ubuntu for PulseView and its libs
$SUDO apt-get update
$SUDO apt-get install -y \
    build-essential cmake pkg-config automake autoconf libtool git wget file \
    g++ doxygen \
    qtbase5-dev qttools5-dev qttools5-dev-tools libqt5svg5-dev \
    libglib2.0-dev libglibmm-2.4-dev libsigc++-2.0-dev \
    libzip-dev libusb-1.0-0-dev libftdi1-dev libhidapi-dev libbluetooth-dev \
    libserialport-dev libboost-dev libboost-filesystem-dev libboost-system-dev libboost-test-dev \
    python3-dev python3-numpy swig

# Build and install libsigrok (C library with C++ bindings)
clone_repo "$LIBSIGROK_REPO" "$LIBSIGROK_REF" libsigrok
cd libsigrok
./autogen.sh && ./configure --prefix=/usr/local --enable-cxx
make -j"$(nproc)" 
$SUDO make install  # Install to /usr/local
cd ..

# Build and install libsigrokdecode (decoder library)
git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode
./autogen.sh && ./configure --prefix=/usr/local
make -j"$(nproc)"
$SUDO make install
cd ..

# Build PulseView (Qt application)
git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview
mkdir build && cd build
# Ensure pkg-config can find the newly installed libs
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release ..
make -j"$(nproc)"
$SUDO make install DESTDIR=AppDir  # Install into AppDir for packaging

# Prepare AppImage using linuxdeploy and its Qt plugin
cd ..
wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
chmod +x linuxdeploy-*.AppImage

# Use linuxdeploy to bundle the AppDir into an AppImage (no Docker, run AppImage directly)
# Running linuxdeploy (will find the Qt plugin in the same directory)
if [ "$APPIMAGE_ARCH" = "x86_64" ]; then
    LINUXDEPLOY_ARCH="x86_64"
else
    LINUXDEPLOY_ARCH="aarch64"
fi

wget -q "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-$LINUXDEPLOY_ARCH.AppImage"
wget -q "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-$LINUXDEPLOY_ARCH.AppImage"
chmod +x linuxdeploy-*.AppImage

./linuxdeploy-$LINUXDEPLOY_ARCH.AppImage --appimage-extract-and-run \
    --appdir build/AppDir \
    --output appimage

# Move AppImage to output directory
mkdir -p "${OUT_DIR:-$HOME/out}/linux/$APPIMAGE_ARCH"
APPIMAGE_FILE=$(ls PulseView*.AppImage | head -1)
if [ -n "$APPIMAGE_FILE" ]; then
    mv "$APPIMAGE_FILE" "${OUT_DIR:-$HOME/out}/linux/$APPIMAGE_ARCH/PulseView-$APPIMAGE_ARCH.AppImage"
    log "Linux AppImage built: ${OUT_DIR:-$HOME/out}/linux/$APPIMAGE_ARCH/PulseView-$APPIMAGE_ARCH.AppImage"
else
    log "ERROR: AppImage file not found"
    exit 1
fi
