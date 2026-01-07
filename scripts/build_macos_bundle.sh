#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    MAC_ARCH="amd64"
    BREW_PREFIX="/usr/local"
else
    MAC_ARCH="arm64"
    BREW_PREFIX="/opt/homebrew"
fi

log "Building macOS bundle for $MAC_ARCH"

# Install required packages including doxygen for C++ bindings
brew install qt@5 glib glibmm libzip libusb hidapi libftdi pkg-config cmake automake libtool python@3 boost libsigc++ doxygen

export PATH="$BREW_PREFIX/opt/qt@5/bin:$PATH"
export PKG_CONFIG_PATH="$BREW_PREFIX/opt/qt@5/lib/pkgconfig:$BREW_PREFIX/opt/glibmm/lib/pkgconfig:$BREW_PREFIX/opt/libsigc++/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

git clone --depth 1 -b "$LIBSERIALPORT_REF" https://github.com/sigrokproject/libserialport.git
cd libserialport && ./autogen.sh && ./configure --prefix=$BREW_PREFIX
make -j"$(sysctl -n hw.ncpu)" && sudo make install && cd ..

clone_repo "$LIBSIGROK_REPO" "$LIBSIGROK_REF" libsigrok
cd libsigrok && ./autogen.sh && ./configure --prefix=$BREW_PREFIX --enable-cxx
make -j"$(sysctl -n hw.ncpu)" && sudo make install && cd ..

git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
cd libsigrokdecode && ./autogen.sh && ./configure --prefix=$BREW_PREFIX
make -j"$(sysctl -n hw.ncpu)" && sudo make install && cd ..

git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview && mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=$BREW_PREFIX/opt/qt@5 -DCMAKE_INSTALL_PREFIX=install -DCMAKE_BUILD_TYPE=Release ..
make -j"$(sysctl -n hw.ncpu)" && make install

cd install
APP_BUNDLE=$(find . -type d -name "*.app" | head -n 1)
if [ -z "$APP_BUNDLE" ]; then
    log "ERROR: No .app bundle found"
    exit 1
fi

$BREW_PREFIX/opt/qt@5/bin/macdeployqt "$APP_BUNDLE" -always-overwrite

mkdir -p "${OUT_DIR:-$HOME/out}/macos/$MAC_ARCH"
cp -r "$APP_BUNDLE" "${OUT_DIR:-$HOME/out}/macos/$MAC_ARCH/"

if command -v hdiutil &> /dev/null; then
    DMG_NAME="PulseView-macOS-$MAC_ARCH.dmg"
    hdiutil create -volname "PulseView" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"
    mv "$DMG_NAME" "${OUT_DIR:-$HOME/out}/macos/$MAC_ARCH/"
fi

log "macOS build completed"
