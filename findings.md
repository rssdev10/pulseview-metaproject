CI/CD Pipeline for Building PulseView (Meta-Project Approach)
Overview and Meta-Project Setup

The goal is to create a meta-project (a separate Git repository) whose sole purpose is to fetch and build PulseView and its dependencies across platforms. This repository will contain the CI/CD workflow configuration (GitHub Actions) and any build scripts or submodule references needed, but not the actual source of PulseView itself. By doing so, we can flexibly choose specific branches of each dependent project (e.g. libsigrok, libsigrokdecode, etc.) to build against, without altering the upstream repositories.

Key idea: The CI pipeline will clone the relevant sigrok sub-projects from the sigrokproject organization at specified branch names, build them in the correct order, and package the final PulseView application for Linux, Windows, and macOS (both amd64 and arm64 architectures). We will use native build agents whenever available, and resort to cross-compilation when a native runner is not available (for example, cross-compiling Windows or macOS ARM builds) as per your requirements.

Branch Selection Mechanism

To allow selecting branches of dependent projects, the CI workflow can be triggered with parameters:

We can use a workflow dispatch trigger in GitHub Actions that accepts inputs for the branch names (or commit SHA) of each component (PulseView, libsigrok, libsigrokdecode, etc.). For example, inputs like pulseview_branch, libsigrok_branch, libsigrokdecode_branch, etc. By default, these can be set to the stable or master branches, but they can be overridden to test specific branches or PRs.

Inside the workflow, these input variables will be used in the build steps to git clone each repository at the specified branch. This avoids needing to update submodules for each branch change; the selection is dynamic at runtime.

Alternatively, the meta-project could include the subprojects as git submodules (so that a combination of versions can be pinned via submodule commits). However, changing submodule references requires commits to the meta-repo. Using workflow inputs gives more on-the-fly flexibility. We can combine approaches if needed (e.g. default to submodule commits for known good combinations, but allow overrides via inputs).

GitHub Actions Workflow Structure

We will use GitHub Actions (since you specified "GitHub CI") to orchestrate the builds. A single workflow (YAML) can define a matrix build to cover all target OS and architectures:

Operating systems: Linux, Windows, macOS.

Architectures: amd64 (aka x86_64) for all, plus arm64 where applicable. For Linux, arm64 could target platforms like Raspberry Pi 64-bit OS; for Windows, arm64 target (Windows 10/11 on ARM); for macOS, the Apple Silicon (M1/M2) builds.

Using a matrix allows parallel builds and a clear definition of each combination. For example:

strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    arch: [amd64, arm64]
    exclude:
      # Exclude combos that are not feasible or need special handling
      - os: windows-latest
        arch: arm64   # (We will handle Windows/ARM64 via cross-compile on x64)
      - os: macos-latest
        arch: arm64   # (If no native arm64 Mac runner is available, handle via cross-compile or separate process)


Each job will run on the appropriate runner and call a series of build steps (detailed per platform below). Where a native runner for a given arch/OS is not available (e.g. Windows arm64, macOS arm64), we configure the job to run on a compatible host and perform cross-compilation. For example, we might run the Windows-arm64 job on a Windows-x64 runner using an arm64 cross-compiler, and similarly run the macOS-arm64 build on an macOS-x64 runner (or use a universal build technique) – this aligns with “yes [use cross-compilation] whenever it is not possible to use a native agent” (your answer to Q2).

Additionally, we will include steps in each job to upload the resulting artifacts (AppImage, .exe installer, .dmg, etc.) so that the CI run produces downloadable application bundles.

Linux Build: AppImage Packaging

For Linux, the aim is to produce a self-contained AppImage for PulseView on both x86_64 and arm64. The AppImage format allows distributing a single runnable file that includes PulseView and all necessary libraries, making it portable across Linux distributions. (The sigrok project already uses AppImages for nightlies
sigrok.org
.)

Build steps on Linux (Ubuntu runner):

Install dependencies: Use apt to install essential build tools and libraries that don’t need to be built from source. For example: sudo apt-get install build-essential cmake pkg-config libglib2.0-dev libglibmm-2.4-dev libzip-dev libusb-1.0-0-dev libftdi1-dev libhidapi-dev libboost-dev qtbase5-dev qtbase5-dev-tools qttools5-dev qttools5-dev-tools qtdeclarative5-dev qtsvg5-dev. These cover compiler, GLib, zlib/zip, libusb, libftdi, HIDAPI, Boost, and Qt5 (PulseView currently uses Qt5). We also ensure Python3 and SWIG are available if needed for libsigrokdecode.

Clone & build libserialport (C library for serial port access): This is a prerequisite for libsigrok. It’s a small CMake or autotools project. Clone sigrokproject/libserialport at the chosen branch, build and install it to a staging directory (e.g., ./install prefix).

Clone & build libsigrok: Clone sigrokproject/libsigrok at the specified branch. This uses the autotools build system. We will run ./autogen.sh && ./configure --prefix=$PWD/install && make -j && make install. This produces libsigrok.so and also builds libsigrokcxx (the C++ bindings) and possibly the Python bindings (if enabled). We ensure the PKG_CONFIG_PATH is pointing to our install/lib/pkgconfig so that downstream finds this installed lib
sigrok.org
sigrok.org
.

Clone & build libsigrokdecode: Clone sigrokproject/libsigrokdecode at the needed branch. This provides protocol decoder scripts (mostly Python). Build/install it (also autotools). The result will install a directory share/libsigrokdecode/decoders/... containing Python decoder modules. We will later package these.

Clone & build PulseView: Clone sigrokproject/pulseview at the chosen branch. PulseView uses CMake. We configure it to use our staging install of the above libs:

Set PKG_CONFIG_PATH=$PWD/install/lib/pkgconfig so CMake can find libsigrok, etc.

Run cmake -DCMAKE_INSTALL_PREFIX=$PWD/install -DCMAKE_BUILD_TYPE=Release -DPYTHON_EXECUTABLE=/usr/bin/python3 . (and any other flags needed, e.g., to include decoders).

Run make -j && make install – this installs PulseView binaries into the staging prefix as well (e.g. install/bin/pulseview, and copies any resources).

Package into AppImage: We can use the official linuxdeployqt tool to bundle the Qt app. We would copy the contents of our install prefix into an AppDir structure and then run linuxdeployqt:

Prepare an AppDir: e.g. create AppDir/usr and move install/bin, install/lib, install/share into AppDir/usr/. Ensure AppDir/usr/bin/pulseview exists.

Run linuxdeployqt AppDir/usr/bin/pulseview -qmldir=... -appimage which will deploy Qt libraries and other dependencies into the AppDir and then produce an AppImage. We should provide a PulseView desktop file and icon for this step (which PulseView’s build might have already, or we create one).

The result will be something like pulseview-x86_64.AppImage. We’d do the same on an arm64 runner (or cross-compile environment) to get an arm64 AppImage. (Note: If a native arm64 Linux runner is not available, we could use QEMU user emulation or cross-compile toolchain to build for arm64 on an x86_64 runner. Since you indicated cross-compiling is acceptable when native agents aren’t available, we can install an aarch64 cross-toolchain on Ubuntu and pass -DCMAKE_TOOLCHAIN_FILE or appropriate compiler flags to build for arm64. Another option is using Docker with an arm64 image on an x64 runner with QEMU.)

Artifact: Upload the AppImage (and perhaps a separate one for debug symbols if needed). The official nightlies provide a debug build AppImage separately
sigrok.org
, but we can focus on release unless debug is required.

This AppImage will be portable on any distro >= Ubuntu 18.04 (as noted in sigrok docs) and contains all necessary libraries and the decoders. Users just download, chmod +x, and run it.

Windows Build: Cross-Compile and Installer

For Windows, we need to produce an installer (or at least an executable bundle) for both 64-bit and 32-bit if needed (though you specified amd64 and arm64). Assuming we target x86_64 and possibly arm64 Windows:

Option 1: Cross-compile using MXE on Linux – This is the approach the sigrok project historically uses for Windows nightlies. They have a script in sigrok-util for cross-compiling with MXE (MinGW cross environment)
GitHub
GitHub
:

MXE is a cross-compilation toolchain that can build Windows binaries on Linux, including many libraries. We can leverage it to avoid the complexity of setting up MSVC or hunting down Windows libs.

We would add a job (on ubuntu-latest runner) dedicated to building Windows artifacts. This job can install MXE or use a Docker image with MXE. It needs a MinGW-w64 cross-compiler and will build all dependencies in one go.

For example, the sigrok script suggests: clone MXE and build required packages:

# Install MXE packages for all dependencies
make MXE_TARGETS=x86_64-w64-mingw32.static.posix \
    MXE_PLUGIN_DIRS=plugins/examples/qt5-freeze \
    gcc glib libzip libusb1 libftdi1 hidapi glibmm qtbase qtimageformats \
    qtsvg qttranslations boost check gendef libieee1284:contentReference[oaicite:6]{index=6}


This will compile all these libraries for the cross-target (it can produce 64-bit or 32-bit by changing MXE_TARGETS). The list includes glib, glibmm, libusb, libftdi, hidapi, Qt5 (base, SVG, etc.), Boost, and more – essentially everything PulseView needs
GitHub
. (The qt5-freeze plugin here was used to lock Qt to 5.7 for XP compatibility
GitHub
, which you may or may not need to do now.)

After MXE builds the libraries, we run the cross-build script (or equivalent steps) to build the projects:

Use the MXE-provided cross-compiler (x86_64-w64-mingw32-gcc for C, and CMake/PKG‑config from MXE) to configure and build libserialport, libsigrok, libsigrokdecode, and PulseView for Windows. The sigrok-cross-mingw script automates this
GitHub
. We can mimic that in our CI by invoking it or translating its steps into the YAML (ensuring it picks the correct branch sources).

This will produce PulseView.exe and all required DLLs. Likely MXE will link many things statically (since .static is used, meaning Qt and others might be linked statically into the binary). If some are shared, MXE would provide .dll files.

The script also uses NSIS to create an installer .exe for ease of distribution. We should install NSIS on the build machine (there’s makensis available) to package the final installer. The nightlies are distributed as installer EXEs
sigrok.org
.

If targeting Windows/ARM64: MXE as of now might not support targeting ARM Windows (MXE mainly targets x86 and x64). For Windows on ARM, an alternative is to use Microsoft’s compiler. This could be done on a Windows runner using MSVC’s ARM64 toolchain. However, building all dependencies (GLib, etc.) with MSVC is complex. Given ARM64 Windows is a less common target, an initial approach might be to skip it or handle it later. If needed, one could attempt to cross-compile using Clang targeting Windows/ARM64 on a Linux runner or use vcpkg to build dependencies for ARM64 on Windows. This is advanced, so initially the focus can be on x64. (Your answer to Q3 was "I don't know", which suggests ARM64 Windows support was uncertain – we can treat it as a future enhancement.)

Option 2: Native build on Windows runner – Alternatively, use a Windows GitHub runner:

Install MSYS2 and use its package manager (Pacman) to install mingw-w64-x86_64-qt5, mingw-w64-x86_64-glib2, etc., then build with MinGW-w64 on Windows. Or use vcpkg with Visual Studio to install packages. This approach is possible but can be more cumbersome to script. Since the MXE cross-compile method is known to work and can be fully automated on Linux, it’s recommended.

Packaging on Windows:

If using the MXE + NSIS route, the sigrok-cross-mingw script will generate an installer (pulseview-NIGHTLY-x86_64-release-installer.exe). We can take inspiration from that. The NSIS installer will include the PulseView.exe, all needed DLLs (for Qt, Glib, etc.), and the Python scripts and firmware. It may also include the USB driver Zadig (the official installer does).

If not using NSIS, a simpler approach is to zip up the PulseView folder with all DLLs. But an installer provides a nicer user experience (shortcuts, uninstaller, etc.). Given sigrok already has an NSIS script (likely in their contrib or util), we should reuse it if possible.

Finally, the GitHub Actions job will upload the installer EXE (and possibly a zip as well if we choose).

Note: Ensure that the firmware files and decoder scripts are included. The build process for libsigrok installs default firmware (e.g. fx2lafw) under share/sigrok-firmware, and libsigrokdecode installs decoders under share/libsigrokdecode. We must package those with the PulseView binary. In MXE build, those would be in the install prefix; the NSIS packaging step should include them. (In the macOS script below, you’ll see explicit steps to include firmware and decoders in the bundle; for Windows, it’s similar – include those directories in the installer so PulseView can find them at runtime.)

macOS Build: .app Bundle Creation

On macOS, we want to produce a PulseView.app bundle (and a .DMG for distribution) for both Intel (amd64) and Apple Silicon (arm64) Macs. If a macOS runner for both architectures is not available, we can build on one and cross-compile or create a universal binary:

Apple’s clang can produce universal binaries if both arch libraries are available. Another approach is to run two builds (one on an Intel runner, one on an M1 self-hosted runner or cross-compiled) and then use lipo to combine. However, since your answer to Q4 indicated no strong preference other than portability, it might be acceptable to produce separate .app for each architecture or just an x86_64 app (which runs via Rosetta on M1). Ideally, though, we aim for native arm64 support.

Build steps on macOS (using Homebrew):

Install dependencies via Homebrew: We use brew to install the needed libraries and tools:

Qt 5 (e.g. brew install qt@5 – newer macOS can use Qt5.15; in sigrok’s scripts they pinned Qt5.5 for backward compatibility
GitHub
, but on modern macOS we can use a more recent Qt5).

Glib, glibmm: brew install glib glibmm

libusb, libftdi, hidapi: brew install libusb libftdi hidapi

libzip, boost, pkg-config, cmake, etc.: brew install libzip boost pkg-config cmake (Boost is needed for certain parts of PulseView, e.g. serialization and timers).

Python3: brew install python@3.x (ensure we have a Python framework, Homebrew’s python3 comes as a Framework by default which is good for bundling).

(If building from git, also install autoconf/automake/libtool for libsigrok’s bootstrap).

Build libserialport, libsigrok, libsigrokdecode similarly to Linux, but using macOS tools:

libserialport: likely ./configure && make && make install into a prefix (say $HOME/opt/sigrok).

libsigrok: ./autogen.sh && ./configure --prefix=$HOME/opt/sigrok && make && make install.

libsigrokdecode: same configure & install to prefix. This will place decoders in $HOME/opt/sigrok/share/libsigrokdecode.
We choose a prefix in our build workspace (not system /usr/local to avoid permission issues on CI runner). For example, $GITHUB_WORKSPACE/install as prefix.

Build PulseView with CMake, pointing to that prefix:

cmake -DCMAKE_PREFIX_PATH=$HOME/opt/sigrok -DCMAKE_INSTALL_PREFIX=$HOME/opt/sigrok \
      -DCMAKE_BUILD_TYPE=Release -DPYTHON_EXECUTABLE=$(brew --prefix python@3)/bin/python3 .
make -j4 && make install


This should produce a PulseView binary and install it along with any data files into the prefix (e.g. the binary in $HOME/opt/sigrok/bin/pulseview, translations or icons if any, in share).

Bundle into a .app: We will create a macOS application bundle manually or via CMake’s BundleUtilities. Given that sigrok has a custom script, let’s follow that approach:

Create a bundle folder structure: PulseView.app/Contents/{MacOS, Frameworks, Resources, share}.

Copy the PulseView binary into Contents/MacOS/.

Copy the share/libsigrokdecode directory into Contents/share/ (preserving the decoders)
GitHub
. Remove any __pycache__ to save space
GitHub
.

Copy the share/sigrok-firmware directory into Contents/share/ (so that logic analyzers’ firmware is included)
GitHub
.

Use macdeployqt on the bundle to pull in Qt frameworks and plugins: e.g. $(brew --prefix qt@5)/bin/macdeployqt PulseView.app
GitHub
. This will copy QtCore, QtWidgets, QtSvg, etc. into Contents/Frameworks and fix their paths.

Copy any additional non-Qt libraries that PulseView depends on, into Contents/Frameworks. For example, libusb, libftdi, hidapi, glib, glibmm, boost libraries, etc. Some of these may not be automatically handled by macdeployqt, so we do it manually:

In sigrok’s script, they manually copied Boost Chrono and Timer dylibs since macdeployqt skipped them
GitHub
. We should copy all needed .dylibs from our prefix or brew into the Frameworks folder (e.g. libsigrok*.dylib, libserialport.dylib, libglib-2.0.dylib, etc.). Ensure their file permissions are correct (644)
GitHub
.

After copying, use install_name_tool to update the PulseView binary and each dylib’s references so that they point to @executable_path/../Frameworks/... instead of the absolute Homebrew paths. For example, the sigrok script fixes the Python framework reference inside libsigrokdecode using install_name_tool -change
GitHub
. We would do similar for any libs referencing /usr/local/opt paths.

Copy the Python framework into Contents/Frameworks/Python.framework. Homebrew’s Python (e.g. 3.x) is a framework located in /usr/local/opt/python@3.X/Frameworks/Python.framework. We can copy that entire framework directory into our app’s Frameworks
GitHub
. Then remove unneeded parts (headers, test files, etc.) to slim it down
GitHub
. This provides an embedded Python runtime for the protocol decoders.

Adjust the libsigrokdecode.dylib to use the embedded Python: Using install_name_tool to point it at our bundled Python (this was done in the script: changing references from Homebrew’s Python to @executable_path/../Frameworks/Python.framework/... inside libsigrokdecode and any other component that links Python
GitHub
).

Add PulseView’s Info.plist and icon: If PulseView source provides these in a contrib folder, copy them into Contents/ (Info.plist in Contents, and .icns icon into Contents/Resources). This ensures the app has the proper metadata
GitHub
.

Finally, create a wrapper script for the binary: The PulseView app when double-clicked should set up environment variables so that the decoders and firmware can be found. Sigrok solves this by renaming the real binary to pulseview.real and installing a wrapper as pulseview that sets PYTHONHOME, SIGROKdecode_DIR, etc.
GitHub
. In our case, we can integrate this in the bundle by creating a shell script or small C++ launcher that sets:

PYTHONHOME = @executable_path/../Frameworks/Python.framework/Versions/3.x

SIGROKDECODE_DIR = @executable_path/../share/libsigrokdecode/decoders

SIGROK_FIRMWARE_DIR = @executable_path/../share/sigrok-firmware

(and possibly SIGROK_DIR if needed, but mainly the above two for decoders/firmware)
and then launches the real PulseView binary. The script from sigrok’s contrib/pulseview does exactly that
GitHub
. We include this in Contents/MacOS (ensuring it’s executable) and adjust Info.plist to point to this launcher as CFBundleExecutable.

At this point, PulseView.app is complete. We then create a DMG image for distribution. We can use the hdiutil command:

hdiutil create "PulseView-${{ github.run_number }}.dmg" -volname "PulseView" -fs HFS+ -srcfolder "PulseView.app"


(The sigrok script uses hdiutil similarly
GitHub
).

Build for arm64: If we have an Apple Silicon runner, we can perform all the above on that platform as well to get a native arm64 app. If we only have an Intel mac runner, one strategy is:

Use Homebrew on Intel Mac to install qt@5 and other deps as universal binaries (Homebrew on Intel can sometimes build universal libs if instructed, or we use brew install --build-bottle etc., but this is non-trivial).

Alternatively, build on Intel for x86_64 and accept that it runs via Rosetta on arm64 (since Big Sur or later is required per documentation
sigrok.org
, Rosetta 2 is available).

For a truly native arm64 build, a self-hosted M1 runner or cross-compiling using Apple's tools would be needed. Cross-compiling on Intel using Apple Clang might be possible by specifying -DCMAKE_OSX_ARCHITECTURES=arm64, but all dependencies (Qt, libs) must also be compiled for arm64. Without an M1 machine, the simpler approach might be to produce just the x86_64 .app. Given the requirement, however, ideally both builds are produced.

If both x64 and arm64 .app are made, we could use the lipo tool to merge the two PulseView binaries (and any native code libs) into a single universal app bundle. This would require careful merging of frameworks as well (Qt frameworks from Qt5 can often be lipo-ed as they are built fat by Homebrew if both arch builds were done). This is an advanced step and might be optional. Shipping two separate DMGs (one for Intel, one for Apple Silicon) is also acceptable.

Artifact: Upload the DMG (or both DMGs for each arch). The CI artifacts for macOS will then be the disk image that users can download and drag-drop the PulseView.app into /Applications.

Throughout the macOS build, we rely on Homebrew to simplify obtaining dependencies. The sigrok packaging script (from sigrok-util) demonstrates many of these steps (copying Boost libs, running macdeployqt, bundling Python, etc.)
GitHub
GitHub
. We have essentially automated those steps in the CI.

Summary of macOS bundling concerns: We must ensure the final PulseView.app/Contents/Frameworks contains all the .dylib shown in your example listing (Boost libs, libusb, libftdi, glib, glibmm, libsigrok, libsigrokdecode, etc., plus the Python.framework). The example directory listing corresponds well with what the above process yields. We also set up the environment (via the wrapper script) so that PulseView finds the embedded Python and decoder scripts at runtime. This results in a portable app bundle that can be run on a Mac without installing anything else (aside from maybe the FTDI driver if not using the built-in one, but libusb should handle most device communications).

Putting it All Together

The GitHub Actions workflow will likely have jobs that do the following:

Checkout meta-project repo, parse input parameters for branch names.

Linux job: run a script or inline commands to build everything and create AppImages for x86_64 and arm64 (maybe using a build matrix or two separate jobs).

Windows job: either (a) run on Ubuntu to cross-compile using MXE (covering 32-bit and/or 64-bit in one job or separate), or (b) run on Windows with MSYS2. The MXE approach is preferred for automation. After building, produce an NSIS installer EXE.

macOS job: run on macos-latest (Intel) to produce the Intel DMG. If an Apple Silicon runner is available or cross-compile approach is manageable, produce the arm64 build as well (could be another job). Otherwise, note that the x64 build will run under Rosetta if needed.

Each job ends by storing artifacts (with appropriate names, e.g. pulseview-nightly-x86_64.AppImage, pulseview-nightly-arm64.AppImage, pulseview-installer-x64.exe, PulseView-mac-x64.dmg, etc.).

By structuring the CI this way, any combination of branches can be built by manually triggering the workflow with parameters, or by scheduling nightly builds of the default branches. This meta-project approach ensures that developers can easily obtain binaries for testing changes across the whole stack (as noted by a sigrok maintainer, providing CI binaries for PRs can greatly help user testing
news.ycombinator.com
).

Finally, we should maintain this meta-project outside the main sigrok codebase (as you mentioned in Q1, "this repo will be located outside of this project" – yes, it’s a separate orchestration repository). It will reference the official repos but not modify them. The result is a robust CI/CD pipeline that continuously produces up-to-date PulseView applications for all major platforms.

References:

Sigrok cross-compilation script for Windows (MXE) – lists required libraries and usage
GitHub
.

Sigrok macOS bundling script – demonstrates copying needed libs and using macdeployqt
GitHub
GitHub
. The script also sets environment via a wrapper
GitHub
 to ensure the bundled Python and decoders are found.
 