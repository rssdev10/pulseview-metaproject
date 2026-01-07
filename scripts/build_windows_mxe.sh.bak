#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"  # strict mode and env vars

# Prepare MXE (M cross environment) repository for cross-compilation
sudo apt-get update && sudo apt-get install -y software-properties-common lsb-release wget
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 86B72ED9
sudo add-apt-repository "deb [arch=amd64] https://pkg.mxe.cc/repos/apt $(lsb_release -sc) main"
sudo apt-get update

# Install MXE base toolchain and required packages (cross-compiler, Qt5, libs)
sudo apt-get install -y mxe-x86-64-w64-mingw32.static-cc \
                        mxe-x86-64-w64-mingw32.static-qtbase \
                        mxe-x86-64-w64-mingw32.static-qttools \
                        mxe-x86-64-w64-mingw32.static-glib \
                        mxe-x86-64-w64-mingw32.static-libzip \
                        mxe-x86-64-w64-mingw32.static-libusb1 \
                        mxe-x86-64-w64-mingw32.static-hidapi \
                        mxe-x86-64-w64-mingw32.static-libftdi1 || true

export PATH=/usr/lib/mxe/usr/bin:$PATH             # Add MXE cross-compiler tools to PATH
export PKG_CONFIG=x86_64-w64-mingw32.static-pkg-config  # Use MXE’s pkg-config for cross builds

# Build and install libserialport for Windows (not provided by MXE packages)
git clone --depth 1 -b "$LIBSERIALPORT_REF" https://github.com/sigrokproject/libserialport.git
cd libserialport
./autogen.sh
./configure --host=x86_64-w64-mingw32.static --prefix=/usr/lib/mxe/usr/x86_64-w64-mingw32.static
make -j"$(nproc)" && make install
cd ..

# Build and install libsigrok (cross) with C++ bindings
clone_repo "$LIBSIGROK_REPO" "$LIBSIGROK_REF" libsigrok
cd libsigrok
./autogen.sh
./configure --host=x86_64-w64-mingw32.static --prefix=/usr/lib/mxe/usr/x86_64-w64-mingw32.static --enable-cxx
make -j"$(nproc)" && make install
cd ..

# Build and install libsigrokdecode (cross)
git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode
./autogen.sh
# Configure for cross, note: Python is required for decoders. (MXE doesn't provide Python, so this may skip Python bindings)
./configure --host=x86_64-w64-mingw32.static --prefix=/usr/lib/mxe/usr/x86_64-w64-mingw32.static || echo "Warning: libsigrokdecode configured with limited Python support"
make -j"$(nproc)" && make install || true  # Continue even if some optional parts fail
cd ..

# Build PulseView using MXE toolchain (CMake)
git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview
mkdir build && cd build
# Use MXE-provided CMake toolchain file for cross-compiling
cmake -DCMAKE_TOOLCHAIN_FILE=/usr/lib/mxe/usr/x86_64-w64-mingw32.static/share/cmake/mxe-conf.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=install-root \
      ..
make -j"$(nproc)" && make install

# Package the Windows build into a zip archive
cd install-root
zip -r ../../pulseview-windows-x86_64.zip ./*
cd ../../
echo "Windows build artifacts packaged: pulseview-windows-x86_64.zip"
