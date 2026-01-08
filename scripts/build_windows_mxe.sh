#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

log "Building Windows x86_64 using MXE (optimized for CI speed)"

# Build/cache location - use /opt/mxe so it's on the root disk (faster than /tmp)
MXE_DIR="/opt/mxe"

# Check if MXE is already cached/built
if [ ! -d "$MXE_DIR" ]; then
    log "Building MXE from source (will be cached for future runs)..."
    cd /tmp
    
    log "Cloning MXE repository..."
    rm -rf mxe 2>/dev/null
    git clone --depth 1 https://github.com/mxe/mxe.git
    cd mxe
    
    log "Building MXE toolchain (this takes ~15-20 minutes, then cached)..."
    
    # Use ccache to speed up compilation on rebuild
    export CCACHE_DIR="${CCACHE_DIR:-/tmp/ccache}"
    mkdir -p "$CCACHE_DIR"
    
    # Build only what we need - the key optimization for speed
    # Skip: doc, fonts, nsis, imagemagick, opencv, etc.
    # Keep only: gcc, glib, glibmm, boost, qt5, libusb, libftdi, libzip
    make -j$(nproc) \
        MXE_TARGETS='x86_64-w64-mingw32.static' \
        MXE_PLUGIN_DIRS='plugins/gcc13' \
        JOBS=$(nproc) \
        cc \
        glib \
        glibmm \
        boost \
        libzip \
        libusb1 \
        libftdi1 \
        qtbase \
        qtsvg
    
    # Verify critical components
    if [ ! -f "usr/bin/x86_64-w64-mingw32.static-gcc" ]; then
        log "ERROR: MXE build failed - gcc not found"
        exit 1
    fi
    
    log "✓ MXE built. Copying to /opt/mxe for caching..."
    sudo mkdir -p /opt
    sudo cp -r . "$MXE_DIR"
    sudo chown -R $(whoami):$(whoami) "$MXE_DIR"  # Fix permissions so we can install into it
else
    log "✓ Using cached MXE toolchain from $MXE_DIR"
fi

# Set up environment
export PATH="$MXE_DIR/usr/bin:$PATH"
export TARGET="x86_64-w64-mingw32.static"
export PREFIX="$MXE_DIR/usr/$TARGET"

# Ensure MXE is in PATH
if ! command -v x86_64-w64-mingw32.static-gcc &> /dev/null; then
    log "ERROR: MXE gcc not found in PATH"
    exit 1
fi
log "✓ MXE toolchain active: $(which x86_64-w64-mingw32.static-gcc)"

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

# Verify C++ bindings were built
if [ ! -f "$PREFIX/lib/pkgconfig/libsigrokcxx.pc" ]; then
    log "ERROR: libsigrokcxx.pc not found. C++ bindings may have failed to build."
    ls -la "$PREFIX/lib/pkgconfig/" || true
    exit 1
fi
log "✓ libsigrokcxx.pc found"
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
    -DDISABLE_DECODER=ON \
    ..

make -j$(nproc) && make install

# Package
log "Creating Windows package..."
mkdir -p "${OUT_DIR:-$HOME/out}/windows/amd64"
cd install
zip -r "${OUT_DIR:-$HOME/out}/windows/amd64/PulseView-Windows-x86_64.zip" .

log "✓ Windows build completed successfully"
