#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

log "Building Windows x86_64 using MXE Docker"

docker run --rm \
    -v "$(pwd):/work" \
    -w /work \
    -e LIBSIGROK_REPO="$LIBSIGROK_REPO" \
    -e LIBSIGROK_REF="$LIBSIGROK_REF" \
    -e LIBSIGROKDECODE_REF="$LIBSIGROKDECODE_REF" \
    -e LIBSERIALPORT_REF="$LIBSERIALPORT_REF" \
    -e PULSEVIEW_REF="$PULSEVIEW_REF" \
    hectorm/mxe:latest \
    bash -c '
        set -euo pipefail
        export PATH="/mxe/usr/bin:$PATH"
        export TARGET="x86_64-w64-mingw32.static"
        export PREFIX="/mxe/usr/$TARGET"
        
        git clone --depth 1 -b "$LIBSERIALPORT_REF" https://github.com/sigrokproject/libserialport.git
        cd libserialport && ./autogen.sh && ./configure --host=$TARGET --prefix=$PREFIX
        make -j$(nproc) && make install && cd ..
        
        if [[ "$LIBSIGROK_REPO" == */* ]]; then
            git clone --depth 1 -b "$LIBSIGROK_REF" "https://github.com/$LIBSIGROK_REPO.git" libsigrok
        else
            git clone --depth 1 -b "$LIBSIGROK_REF" "https://github.com/sigrokproject/libsigrok.git" libsigrok
        fi
        cd libsigrok && ./autogen.sh && ./configure --host=$TARGET --prefix=$PREFIX --enable-cxx
        make -j$(nproc) && make install && cd ..
        
        git clone --depth 1 -b "$LIBSIGROKDECODE_REF" https://github.com/sigrokproject/libsigrokdecode.git
        cd libsigrokdecode && ./autogen.sh && ./configure --host=$TARGET --prefix=$PREFIX || true
        make -j$(nproc) && make install || true && cd ..
        
        git clone --depth 1 -b "$PULSEVIEW_REF" https://github.com/sigrokproject/pulseview.git
        cd pulseview && mkdir build && cd build
        $TARGET-cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=install ..
        make -j$(nproc) && make install
        
        mkdir -p /work/out/windows/amd64 && cd install
        zip -r /work/out/windows/amd64/PulseView-Windows-x86_64.zip .
    '

log "Windows build completed"
