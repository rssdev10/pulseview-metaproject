# PulseView CI/CD Debugging Summary

## Issues Fixed

### 1. Workflow Configuration
**Problem**: Using default sigrokproject/libsigrok instead of custom branch  
**Solution**: Changed defaults to use `rssdev10/libsigrok` with `siglent_sds800` branch

**Problem**: Missing environment variables for sigrok-cli and sigrok-util  
**Solution**: Added `SIGROK_CLI_REF` and `SIGROK_UTIL_REF` to workflow env

**Problem**: macOS-13 runner deprecated  
**Solution**: Updated to use `macos-15-large` for Intel builds, `macos-14` for ARM64

### 2. Docker/Package Conflicts
**Problem**: `docker.io` package conflicts with containerd on GitHub runners  
**Solution**: Removed docker.io from apt install (Docker is pre-installed on runners)

**Problem**: Docker image `hectorm/mxe:latest` doesn't exist  
**Solution**: Changed to `skybon/mxe-qt5:latest` which is maintained and available

### 3. Build Dependencies
**Problem**: "libsigrok C++ bindings missing" error  
**Solution**: Added required packages:
- `g++` - C++ compiler
- `doxygen` - Required for C++ bindings documentation
- `libboost-filesystem-dev`, `libboost-system-dev`, `libboost-test-dev` - Complete boost libraries
- `python3-numpy` - Python bindings support

### 4. Container Compatibility
**Problem**: `sudo: command not found` in Docker containers  
**Solution**: Made scripts container-aware - detect if running in container and skip sudo:
```bash
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    SUDO=""
else
    SUDO="sudo"
fi
```

### 5. Library Path Issues
**Problem**: Freshly built libraries not found by subsequent builds  
**Solution**: Added `LD_LIBRARY_PATH` export in Linux build:
```bash
export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
```

### 6. gh run watch Hanging
**Problem**: Using `gh run watch` directly can hang and crash VS Code  
**Solution**: Created `watch-workflow.sh` script that:
- Polls status every 30 seconds instead of streaming
- Can be safely interrupted with Ctrl+C
- Won't hang the terminal or IDE
- Shows artifacts when complete

## Files Modified

1. **`.github/workflows/build.yml`**
   - Updated default libsigrok repo and branch
   - Added missing environment variables
   - Fixed macOS runner labels
   - Removed docker.io dependency

2. **`scripts/common.sh`**
   - Added `log()` function for timestamped logging
   - Added `need()` function to check for required commands
   - Added `checkout_repo()` for sigrok dependencies
   - Added defaults for all environment variables

3. **`scripts/build_linux_appimage.sh`**
   - Added architecture detection
   - Made container-aware (conditional sudo)
   - Added all required dependencies for C++ bindings
   - Fixed output directory creation
   - Added proper AppImage naming

4. **`scripts/build_windows_mxe.sh`**
   - Complete rewrite using Docker-based MXE
   - Changed to `skybon/mxe-qt5` image
   - Simplified build process
   - Proper output directory handling

5. **`scripts/build_macos_bundle.sh`**
   - Added architecture detection
   - Added doxygen dependency
   - Fixed Homebrew prefix detection
   - Added DMG creation
   - Proper output directory handling

## New Files Created

1. **`README.md`**
   - Comprehensive usage documentation
   - Workflow input descriptions
   - Safe workflow watching instructions
   - Debugging guidance

2. **`watch-workflow.sh`**
   - Safe workflow monitoring script
   - Prevents hanging VS Code
   - Shows progress and artifacts

## Testing Commands

### Trigger workflow
```bash
gh workflow run build.yml \
  -f pulseview_ref=master \
  -f libsigrok_repo=rssdev10/libsigrok \
  -f libsigrok_ref=siglent_sds800 \
  -f libsigrokdecode_ref=master \
  -f libserialport_ref=master \
  -f sigrok_cli_ref=master \
  -f sigrok_util_ref=master
```

### Watch safely
```bash
./watch-workflow.sh
```

### Check status manually
```bash
gh run list --workflow="build.yml" --limit 5
gh run view <RUN_ID>
gh run view <RUN_ID> --log-failed
```

## Expected Artifacts

Upon successful build:
- **Linux**: `PulseView-x86_64.AppImage`, `PulseView-aarch64.AppImage`
- **Windows**: `PulseView-Windows-x86_64.zip`
- **macOS**: `PulseView.app` (in separate arm64 and amd64 artifacts), optional DMG files

## Next Steps

1. Monitor the latest workflow run for any remaining issues
2. If builds succeed, test the generated artifacts on target platforms
3. Consider adding automatic GitHub releases for successful builds
4. May need to tune build times or add caching for faster iterations
5. Document any platform-specific testing procedures

## Commits Made

1. `e8ea2bd` - Fix CI/CD workflow for PulseView builds (initial fixes)
2. `07fefdd` - Add README and fix macOS runner deprecation
3. `b2d71dd` - Fix build dependency and Docker issues (final fixes)
