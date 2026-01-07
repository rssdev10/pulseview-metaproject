# PulseView CI/CD Meta-Project

This repository contains CI/CD workflows to build PulseView across multiple platforms (Windows, Linux, macOS) with configurable branches for all sigrok dependencies.

## Purpose

This is a git meta-project designed solely for building PulseView in CI/CD. It allows you to select specific branches of dependent projects from the [sigrokproject GitHub organization](https://github.com/orgs/sigrokproject/repositories).

## Supported Platforms

Final artifacts are generated for:
- **Windows**: x86_64 (amd64)
- **Linux**: x86_64 and aarch64 AppImages
- **macOS**: arm64 (Apple Silicon) and amd64 (Intel)

## Workflow Inputs

The build workflow accepts the following inputs to customize which branches to use:

- `pulseview_ref`: PulseView branch/tag/SHA (default: `master`)
- `libsigrok_repo`: libsigrok repository (default: `rssdev10/libsigrok`)
- `libsigrok_ref`: libsigrok branch/tag/SHA (default: `siglent_sds800`)
- `libsigrokdecode_ref`: libsigrokdecode branch/tag/SHA (default: `master`)
- `libserialport_ref`: libserialport branch/tag/SHA (default: `master`)
- `sigrok_cli_ref`: sigrok-cli branch/tag/SHA (default: `master`)
- `sigrok_util_ref`: sigrok-util branch/tag/SHA (default: `master`)

## Running the Workflow

### Via GitHub Web Interface

1. Go to Actions → Build PulseView (multi-platform)
2. Click "Run workflow"
3. Select the branch and enter the desired refs
4. Click "Run workflow"

### Via GitHub CLI

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

## Safely Watching Workflow Progress

**⚠️ Warning**: Using `gh run watch` directly can hang and crash VS Code. Instead, use the provided script:

```bash
./watch-workflow.sh
```

This script:
- Polls the workflow status every 30 seconds
- Won't hang your terminal or IDE
- Shows progress and completion status
- Displays artifacts when the build completes
- Can be safely interrupted with Ctrl+C

### Alternative: Check Status Manually

```bash
# List recent runs
gh run list --workflow="build.yml" --limit 5

# View specific run
gh run view <RUN_ID>

# View logs of failed jobs only
gh run view <RUN_ID> --log-failed
```

## Build Artifacts

Upon successful completion, the workflow produces:

### Linux
- `PulseView-x86_64.AppImage` - Linux x86_64 AppImage
- `PulseView-aarch64.AppImage` - Linux ARM64 AppImage

### Windows
- `PulseView-Windows-x86_64.zip` - Windows executable and dependencies

### macOS
- `PulseView.app` - macOS application bundle (separate builds for Intel and Apple Silicon)
- `PulseView-macOS-{arch}.dmg` - Disk image for easy installation (if created)

## macOS Frameworks

For macOS builds, the final application bundle includes all necessary frameworks in `/Applications/PulseView.app/Contents/Frameworks`:

- libboost_* (chrono, filesystem, serialization, system, timer, unit_test_framework)
- libffi, libftdi1, libgio, libglib, libglibmm, libgmodule, libgobject
- libhidapi, libintl, libpcre, libserialport
- libsigc, libsigrok, libsigrokcxx, libsigrokdecode
- libusb, libzip

## Debugging Build Failures

1. **Check the logs**:
   ```bash
   gh run view <RUN_ID> --log-failed | less
   ```

2. **Look for common issues**:
   - Missing dependencies
   - Compilation errors
   - Repository access issues
   - Docker/MXE toolchain problems

3. **Test scripts locally**:
   ```bash
   # Set environment variables
   export LIBSIGROK_REPO="rssdev10/libsigrok"
   export LIBSIGROK_REF="siglent_sds800"
   export PULSEVIEW_REF="master"
   # ... (set other vars)
   
   # Run the appropriate build script
   ./scripts/build_linux_appimage.sh
   # or
   ./scripts/build_macos_bundle.sh
   # or
   ./scripts/build_windows_mxe.sh
   ```

## Files

- `.github/workflows/build.yml` - Main GitHub Actions workflow
- `scripts/common.sh` - Common functions and environment setup
- `scripts/build_linux_appimage.sh` - Linux AppImage build script
- `scripts/build_macos_bundle.sh` - macOS bundle build script  
- `scripts/build_windows_mxe.sh` - Windows cross-compilation script (using MXE via Docker)
- `watch-workflow.sh` - Safe workflow watcher script
- `findings.md` - General findings about the components

## Contributing

When making changes:

1. Test the workflow with various branch combinations
2. Ensure all three platforms build successfully
3. Verify artifacts are correctly generated
4. Update this README if adding new features

## License

This meta-project is provided as-is for building PulseView. Refer to the individual sigrok project repositories for their respective licenses.
