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
cd libsigrokdecode && ./autogen.sh && ./configure --prefix=$BREW_PREFIX --disable-python
make -j"$(sysctl -n hw.ncpu)" && sudo make install && cd ..

git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
cd pulseview && mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH=$BREW_PREFIX/opt/qt@5 -DCMAKE_INSTALL_PREFIX=install -DCMAKE_BUILD_TYPE=Release ..
make -j"$(sysctl -n hw.ncpu)" && make install

cd install

# Create .app bundle from the binary (PulseView doesn't create it by default)
if [ ! -d "PulseView.app" ] && [ -f "bin/pulseview" ]; then
    log "Creating PulseView.app bundle"
    mkdir -p PulseView.app/Contents/MacOS
    cp bin/pulseview PulseView.app/Contents/MacOS/
    
    # Create Info.plist
    cat > PulseView.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>pulseview</string>
    <key>CFBundleIdentifier</key>
    <string>org.sigrok.PulseView</string>
    <key>CFBundleName</key>
    <string>PulseView</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.5.0</string>
</dict>
</plist>
EOF
fi

APP_BUNDLE="PulseView.app"
if [ ! -d "$APP_BUNDLE" ]; then
    log "ERROR: Failed to create .app bundle"
    exit 1
fi

$BREW_PREFIX/opt/qt@5/bin/macdeployqt "$APP_BUNDLE" -always-overwrite

# Bundle Python framework for libsigrokdecode
# libsigrokdecode requires Python to run protocol decoders (--disable-python only disables Python *bindings*)
# We need to include Python.framework in the bundle
log "Bundling Python framework for libsigrokdecode"
PYTHON_VERSION=$(ls $BREW_PREFIX/opt/ | grep "python@" | head -1)
if [ -n "$PYTHON_VERSION" ]; then
    PYTHON_FW="$BREW_PREFIX/opt/$PYTHON_VERSION/Frameworks/Python.framework"
    if [ -d "$PYTHON_FW" ]; then
        log "Copying Python.framework from $PYTHON_FW"
        mkdir -p "$APP_BUNDLE/Contents/Frameworks"
        cp -R "$PYTHON_FW" "$APP_BUNDLE/Contents/Frameworks/"
        
        # Fix library paths in libsigrokdecode to use bundled Python
        SIGROKDECODE_DYLIB="$APP_BUNDLE/Contents/Frameworks/libsigrokdecode.4.dylib"
        if [ -f "$SIGROKDECODE_DYLIB" ]; then
            PYTHON_PATH=$(otool -L "$SIGROKDECODE_DYLIB" | grep "Python.framework" | awk '{print $1}')
            if [ -n "$PYTHON_PATH" ]; then
                log "Updating libsigrokdecode Python.framework path"
                install_name_tool -change "$PYTHON_PATH" "@loader_path/../Frameworks/Python.framework/Versions/3.11/Python" "$SIGROKDECODE_DYLIB"
            fi
        fi
    else
        log "WARNING: Python.framework not found at $PYTHON_FW"
    fi
else
    log "WARNING: Could not detect Python version"
fi

# Remove quarantine attribute to prevent "damaged" warning
log "Removing quarantine attributes"
xattr -cr "$APP_BUNDLE"

# Ad-hoc sign the app (no certificate needed for local use)
log "Ad-hoc signing the application"
codesign --force --deep --sign - "$APP_BUNDLE" || log "Warning: codesign failed, app may show security warning"

mkdir -p "${OUT_DIR:-$HOME/out}/macos/$MAC_ARCH"
cp -r "$APP_BUNDLE" "${OUT_DIR:-$HOME/out}/macos/$MAC_ARCH/"

if command -v hdiutil &> /dev/null; then
    DMG_NAME="PulseView-macOS-$MAC_ARCH.dmg"
    log "Creating DMG: $DMG_NAME"
    hdiutil create -volname "PulseView" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"
    
    # Remove quarantine from DMG as well
    xattr -c "$DMG_NAME" || true
    
    mv "$DMG_NAME" "${OUT_DIR:-$HOME/out}/macos/$MAC_ARCH/"
fi

log "macOS build completed"
