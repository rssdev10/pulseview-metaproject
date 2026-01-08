#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

log "Building Windows x86_64 by compiling MXE from source"

# MXE apt repository is broken, so we build from source
cd /tmp

if [ ! -d "/tmp/mxe" ]; then
    log "Cloning MXE repository..."
    git clone --depth 1 https://github.com/mxe/mxe.git
fi

cd mxe

log "Building MXE toolchain (this will take 20-30 minutes)..."

# Build only the packages we need
make -j$(nproc) \
    MXE_TARGETS='x86_64-w64-mingw32.static' \
    MXE_PLUGIN_DIRS='plugins/gcc13' \
    cc \
    qtbase \
    qtsvg \
    glibmm \
    boost \
    glib \
    libzip \
    libusb1 \
    libftdi1

# Set up environment
export PATH="/tmp/mxe/usr/bin:$PATH"
export TARGET="x86_64-w64-mingw32.static"
export PREFIX="/tmp/mxe/usr/$TARGET"

# Go back to workspace
cd "$GITHUB_WORKSPACE" || cd "$(pwd)"

log "Building libserialport..."
git clone --depth 1 -b "$LIBSERIALPORT_REF" https://github.com/sigrokproject/libserialport.git
cd libserialport
./autogen.sh
./configure --host=$TARGET --prefix=$PREFIX
make -j$(nproc) && make install
cd ..

log "Building libsigrok..."
if [[ "$LIBSIGROK_REPO" == */* ]]; then
    git clone --depth 1 -b "$LIBSIGROK_REF" "https://github.com/$LIBSIGROK_REPO.git" libsigrok
else
    git clone --depth 1 -b "$LIBSIGROK_REF" "https://github.com/sigrokproject/libsigrok.git" libsigrok
fi
cd libsigrok
./autogen.sh
./configure --host=$TARGET --prefix=$PREFIX --enable-cxx
make -j$(nproc) && make install
cd ..

log "Building libsigrokdecode (optional)..."
git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode
./autogen.sh
./configure --host=$TARGET --prefix=$PREFIX --disable-python || true
make -j$(nproc) && make install || true
cd ..

log "Building PulseView..."
git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview
mkdir build && cd build

# Ensure pkg-config can see MXE-built libraries
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Use MXE's CMake wrapper
$TARGET-cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=install \
    ..

make -j$(nproc) && make install

# Package
log "Creating Windows package..."
mkdir -p "${OUT_DIR:-$HOME/out}/windows/amd64"
cd install
zip -r "${OUT_DIR:-$HOME/out}/windows/amd64/PulseView-Windows-x86_64.zip" .

log "Windows build completed successfully"
