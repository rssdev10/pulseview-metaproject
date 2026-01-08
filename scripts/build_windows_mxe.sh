#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

log "Building Windows x86_64 using MXE (native)"

# Install MXE from official repository
sudo apt-get update
sudo apt-get install -y software-properties-common lsb-release wget gnupg

# Add MXE repository
wget -qO- https://pkg.mxe.cc/repos/apt/client-conf/mxeapt.gpg | sudo gpg --dearmor -o /usr/share/keyrings/mxeapt.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mxeapt.gpg] https://pkg.mxe.cc/repos/apt $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/mxeapt.list

sudo apt-get update

# Install minimal MXE toolchain for static builds
sudo apt-get install -y \
    mxe-x86-64-w64-mingw32.static-cc \
    mxe-x86-64-w64-mingw32.static-qtbase \
    mxe-x86-64-w64-mingw32.static-qtsvg \
    mxe-x86-64-w64-mingw32.static-boost \
    mxe-x86-64-w64-mingw32.static-glib \
    mxe-x86-64-w64-mingw32.static-libzip \
    mxe-x86-64-w64-mingw32.static-libusb1 \
    mxe-x86-64-w64-mingw32.static-libftdi1 || {
    log "WARNING: Some MXE packages failed to install, trying alternative approach"
    
    # If packages fail, try building from MXE source
    log "Falling back to manual MXE build (this will take longer)"
    cd /tmp
    git clone https://github.com/mxe/mxe.git
    cd mxe
    make MXE_TARGETS='x86_64-w64-mingw32.static' \
         MXE_PLUGIN_DIRS=plugins/gcc12 \
         cc qtbase qtsvg boost glib libzip libusb1 libftdi1 -j$(nproc)
    export PATH="/tmp/mxe/usr/bin:$PATH"
}

# Set up MXE environment
export PATH="/usr/lib/mxe/usr/bin:$PATH"
export TARGET="x86_64-w64-mingw32.static"
export PREFIX="/usr/lib/mxe/usr/$TARGET"

# Build libserialport
cd "$GITHUB_WORKSPACE" || cd /work || cd "$(pwd)"
git clone --depth 1 -b "$LIBSERIALPORT_REF" https://github.com/sigrokproject/libserialport.git
cd libserialport
./autogen.sh
./configure --host=$TARGET --prefix=$PREFIX
make -j$(nproc) && make install
cd ..

# Build libsigrok
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

# Build libsigrokdecode (may fail on Windows, that's OK)
git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode
./autogen.sh
./configure --host=$TARGET --prefix=$PREFIX || true
make -j$(nproc) && make install || true
cd ..

# Build PulseView
git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview
mkdir build && cd build

# Use MXE's CMake wrapper
$TARGET-cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=install \
    ..

make -j$(nproc) && make install

# Package
mkdir -p "${OUT_DIR:-$HOME/out}/windows/amd64"
cd install
zip -r "${OUT_DIR:-$HOME/out}/windows/amd64/PulseView-Windows-x86_64.zip" .

log "Windows build completed"
