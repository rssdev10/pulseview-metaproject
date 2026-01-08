#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

log "Building Windows x86_64 using apt-installed MXE (Ubuntu 20.04)"

# MXE from Ubuntu 20.04 apt repo is pre-built and fast
export PATH="/usr/lib/mxe/usr/bin:$PATH"
export TARGET="x86_64-w64-mingw32.static"
export PREFIX="/usr/lib/mxe/usr/$TARGET"

# Go to workspace
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

# Verify C++ bindings were built
if [ ! -f "$PREFIX/lib/pkgconfig/libsigrokcxx.pc" ]; then
    log "ERROR: libsigrokcxx.pc not found. C++ bindings may have failed to build."
    ls -la "$PREFIX/lib/pkgconfig/" || true
    exit 1
fi
log "✓ libsigrokcxx.pc found at $PREFIX/lib/pkgconfig/libsigrokcxx.pc"
cd ..

# Skip libsigrokdecode on Windows - it requires Python headers
log "Skipping libsigrokdecode (requires Python, not available on Windows static build)..."

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
