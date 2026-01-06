#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need otool
need install_name_tool
need rsync
need zip

PREFIX="${1:?prefix path}"
OUTDIR="${2:?output dir}"

APPDIR="$OUTDIR/PulseView.app"
CONTENTS="$APPDIR/Contents"
MACOS="$CONTENTS/MacOS"
FW="$CONTENTS/Frameworks"

rm -rf "$APPDIR"
mkdir -p "$MACOS" "$FW" "$CONTENTS/Resources"

log "Locating PulseView executable…"
PV_BIN="$(find "$PREFIX" -type f -perm +111 -name "pulseview" -o -name "PulseView" 2>/dev/null | head -n 1 || true)"
if [ -z "$PV_BIN" ]; then
  echo "Could not find PulseView binary in prefix: $PREFIX" >&2
  exit 2
fi

cp -v "$PV_BIN" "$MACOS/PulseView"

# Minimal Info.plist
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>PulseView</string>
  <key>CFBundleIdentifier</key><string>org.sigrok.PulseView</string>
  <key>CFBundleName</key><string>PulseView</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.0.0</string>
  <key>CFBundleShortVersionString</key><string>0.0.0</string>
</dict>
</plist>
PLIST

log "Bundling Qt frameworks using macdeployqt (if available)…"
if command -v macdeployqt >/dev/null 2>&1; then
  macdeployqt "$APPDIR" -verbose=1 || true
fi

# Copy prefix libs into Frameworks (best-effort)
log "Copying prefix libraries into Contents/Frameworks…"
rsync -a "$PREFIX/lib/" "$FW/" || true

# Fix dylib install names to use @rpath/@executable_path
fix_links_for_bin() {
  local bin="$1"
  otool -L "$bin" | tail -n +2 | awk '{print $1}' | while read -r dep; do
    case "$dep" in
      /System/*|/usr/lib/*) continue;;
    esac

    local base="$(basename "$dep")"
    if [ -f "$dep" ]; then
      cp -n "$dep" "$FW/$base" || true
    elif [ -f "$FW/$base" ]; then
      : # already copied
    fi

    if [ -f "$FW/$base" ]; then
      install_name_tool -change "$dep" "@executable_path/../Frameworks/$base" "$bin" || true
    fi
  done
}

log "Rewriting linkage for main binary…"
fix_links_for_bin "$MACOS/PulseView"

log "Rewriting linkage for bundled dylibs (one pass)…"
find "$FW" -maxdepth 1 -type f \( -name "*.dylib" -o -name "*.so" \) | while read -r lib; do
  fix_links_for_bin "$lib"
  install_name_tool -id "@executable_path/../Frameworks/$(basename "$lib")" "$lib" || true
done

log "Final bundle tree (Frameworks) sample:"
ls -la "$FW" | head -n 80 || true

log "Packaging…"
cd "$OUTDIR"
zip -r "PulseView-macos-$(uname -m).zip" "PulseView.app" >/dev/null
ls -la "$OUTDIR"
