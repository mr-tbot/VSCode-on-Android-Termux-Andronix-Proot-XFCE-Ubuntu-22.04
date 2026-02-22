# SDK & Tool Requirements for Proot Development Environment

This document details every SDK and tool the installer can set up, including compatibility notes, download sources, and manual installation instructions.

---

## Compatibility Matrix

| SDK / Tool | arm64 (aarch64) | x64 (amd64) | Install Method | Auto-Install |
|------------|:---:|:---:|----------------|:---:|
| VSCode | ✅ | ✅ | apt (Microsoft repo) | ✅ |
| Chromium | ✅ | ✅ | apt | ✅ |
| Google Chrome | ❌ | ✅ | N/A for arm64 | ❌ |
| Firefox | ✅ | ✅ | apt / PPA | ✅ |
| Firefox ESR | ✅ | ✅ | PPA | ✅ |
| Node.js | ✅ | ✅ | nvm | ✅ |
| Python 3 | ✅ | ✅ | apt | ✅ |
| OpenJDK 17 | ✅ | ✅ | apt | ✅ |
| Android SDK CLI | ✅ | ✅ | zip download | ✅ |
| Gradle | ✅ | ✅ | zip download | ✅ |
| Flutter | ✅ | ✅ | git clone | ✅ |
| Rust | ✅ | ✅ | rustup | ✅ |
| Go | ✅ | ✅ | tar download | ✅ |
| .NET SDK | ✅ | ✅ | install script | ✅ |
| Git + LFS | ✅ | ✅ | apt | ✅ |
| GitHub CLI | ✅ | ✅ | apt (GitHub repo) | ✅ |
| NDI SDK | ✅ | ✅ | Manual (registration) | ⚠️ Guided |
| Android Studio | ❌ | ✅ | N/A (too heavy for proot) | ❌ |
| Docker | ❌ | ❌ | N/A (needs kernel) | ❌ |

---

## Core Components

### Visual Studio Code
- **What**: Microsoft's code editor with extension ecosystem
- **Why**: Primary IDE for cross-device development
- **arm64**: ✅ Official arm64 .deb packages
- **Install**: Via Microsoft apt repository
- **Proot notes**: Requires `--no-sandbox` flag, `password-store=basic` for keyring
- **Repo**: `https://packages.microsoft.com/repos/code`
- **Manual install**:
  ```bash
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg
  echo "deb [arch=arm64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
  apt update && apt install code
  ```

### Browser (Chromium / Firefox)
- **Chromium**: Open-source Chrome base. Available for arm64 via apt. Best tested in proot.
- **Firefox**: Available via Mozilla PPA (apt-based, since snap doesn't work in proot).
- **Firefox ESR**: Extended Support Release from Mozilla PPA.
- **Google Chrome**: ❌ NOT available for arm64 Linux. Google only provides x64 .deb packages.
- **Proot notes**: Chromium needs `--no-sandbox --disable-gpu`. Firefox needs `MOZ_DISABLE_CONTENT_SANDBOX=1`.

---

## Development SDKs

### Node.js (via nvm)
- **What**: JavaScript runtime + npm package manager
- **Why**: Web development, React Native, Electron apps, build tools
- **arm64**: ✅ Native binaries via nvm
- **Version**: LTS (currently 20.x)
- **Install**: nvm (Node Version Manager) — allows multiple versions
- **URL**: https://github.com/nvm-sh/nvm
- **Manual install**:
  ```bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  source ~/.bashrc
  nvm install --lts
  nvm use --lts
  ```
- **Proot notes**: Works perfectly. Use `--max-old-space-size=512` for heavy builds.
- **Useful global packages**: `yarn`, `pnpm`, `typescript`, `eslint`, `@angular/cli`

### Python 3
- **What**: Python interpreter + pip + venv
- **Why**: Scripting, automation, Django/Flask, data science, ML tools
- **arm64**: ✅ Native via apt
- **Version**: 3.10+ (Ubuntu 22.04 ships 3.10)
- **Install**: apt
- **Manual install**:
  ```bash
  apt install python3 python3-pip python3-venv python3-dev
  ```
- **Proot notes**: Works perfectly. numpy/scipy may need build essentials for compilation.

### Java JDK 17 (OpenJDK)
- **What**: Java Development Kit
- **Why**: Android development, Gradle builds, Spring/Java apps
- **arm64**: ✅ Native via apt
- **Version**: OpenJDK 17 (LTS)
- **Install**: apt
- **Manual install**:
  ```bash
  apt install openjdk-17-jdk
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
  ```
- **Proot notes**: Works well. May need reduced heap for Gradle: `-Xmx512m`

### Android SDK Command-Line Tools
- **What**: Android build tools (sdkmanager, aapt2, d8, zipalign, apksigner)
- **Why**: Build, sign, and package Android APKs without Android Studio
- **arm64**: ✅ Official arm64 command-line tools
- **Version**: Latest (auto-updates via sdkmanager)
- **Install**: Zip download from Google
- **URL**: https://developer.android.com/studio#command-line-tools-only
- **Direct download**: `https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip`
- **Manual install**:
  ```bash
  mkdir -p /opt/android-sdk/cmdline-tools
  wget -O /tmp/cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  unzip /tmp/cmdline-tools.zip -d /opt/android-sdk/cmdline-tools/
  mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest
  export ANDROID_HOME=/opt/android-sdk
  export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
  yes | sdkmanager --licenses
  sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"
  ```
- **Proot notes**: Works for CLI builds. Cannot run emulator (no KVM).
- **Build an APK from command line**:
  ```bash
  # Compile, dex, package, sign — all CLI
  sdkmanager "build-tools;34.0.0" "platforms;android-34"
  # Then use aapt2, d8, zipalign, apksigner
  ```

### Gradle
- **What**: Build automation tool (used by Android, Java, Kotlin projects)
- **Why**: Required for Android app builds, many Java/Kotlin projects
- **arm64**: ✅ Pure Java, runs on any platform with JDK
- **Version**: 8.10.2 (latest stable)
- **Install**: Zip download
- **URL**: https://gradle.org/releases/
- **Manual install**:
  ```bash
  wget -O /tmp/gradle.zip https://services.gradle.org/distributions/gradle-8.10.2-bin.zip
  mkdir -p /opt/gradle
  unzip /tmp/gradle.zip -d /opt/gradle
  ln -sf /opt/gradle/gradle-8.10.2/bin/gradle /usr/local/bin/gradle
  ```
- **Proot notes**: Reduce memory usage:
  ```properties
  # ~/.gradle/gradle.properties
  org.gradle.jvmargs=-Xmx512m -XX:MaxMetaspaceSize=256m
  org.gradle.daemon=false
  org.gradle.parallel=false
  ```

### Flutter SDK
- **What**: Google's cross-platform UI framework
- **Why**: Build Android, iOS, web, desktop apps from single codebase
- **arm64**: ✅ Native arm64 support
- **Version**: Stable channel (latest)
- **Install**: Git clone from official repo
- **URL**: https://flutter.dev/docs/get-started/install/linux
- **Manual install**:
  ```bash
  apt install curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev
  git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
  export PATH="/opt/flutter/bin:$PATH"
  flutter config --no-analytics
  ```
- **Proot notes**:
  - `flutter doctor` will warn about missing Chrome and Android Studio — this is expected
  - Use `flutter build apk --debug` for Android builds (release builds need signing)
  - Web builds work: `flutter build web`
  - Cannot run Android emulator in proot

### Rust
- **What**: Systems programming language
- **Why**: Performance-critical code, CLI tools, WebAssembly, system utilities
- **arm64**: ✅ Native via rustup
- **Version**: Latest stable
- **Install**: rustup installer
- **URL**: https://rustup.rs/
- **Manual install**:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source ~/.cargo/env
  ```
- **Proot notes**: Works well. Cross-compilation targets available via `rustup target add`.

### Go
- **What**: Google's compiled language
- **Why**: Cloud tools, CLI apps, web services, system utilities
- **arm64**: ✅ Official arm64 binaries
- **Version**: 1.22.5 (latest stable)
- **Install**: Tar download from go.dev
- **URL**: https://go.dev/dl/
- **Manual install**:
  ```bash
  wget -O /tmp/go.tar.gz https://go.dev/dl/go1.22.5.linux-arm64.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
  export GOPATH="$HOME/go"
  ```
- **Proot notes**: Works perfectly. `go build` and `go test` run fine.

### .NET SDK
- **What**: Microsoft's cross-platform development framework
- **Why**: C# applications, ASP.NET web apps, .NET MAUI mobile apps
- **arm64**: ✅ Official arm64 builds
- **Version**: 8.0 (LTS)
- **Install**: Microsoft install script
- **URL**: https://dot.net/v1/dotnet-install.sh
- **Manual install**:
  ```bash
  wget -O /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh
  chmod +x /tmp/dotnet-install.sh
  /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet
  ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet
  export DOTNET_ROOT=/usr/share/dotnet
  ```
- **Proot notes**: Works for building. Hot reload may be unreliable.

### Git + Git LFS + GitHub CLI
- **What**: Version control, large file support, GitHub integration
- **Why**: Essential for syncing work between devices via GitHub
- **arm64**: ✅ All available via apt
- **Install**: apt (git, git-lfs) + GitHub CLI repo
- **Manual install**:
  ```bash
  apt install git git-lfs
  git lfs install
  
  # GitHub CLI
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=arm64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
  apt update && apt install gh
  gh auth login
  ```

### Build Essentials
- **What**: gcc, g++, make, cmake, pkg-config, autotools
- **Why**: Compile native modules, C/C++ development, build dependencies
- **arm64**: ✅ All native via apt
- **Install**: apt
- **Manual install**:
  ```bash
  apt install build-essential gcc g++ make cmake pkg-config autoconf automake libtool ninja-build libssl-dev zlib1g-dev libffi-dev
  ```

---

## Special SDKs

### NDI SDK (Network Device Interface)
- **What**: Vizrt/NewTek's network video protocol SDK
- **Why**: NDI-enabled app development, video over IP
- **arm64**: ✅ Linux arm64 build available
- **Version**: Latest (currently 6.x)
- **Install**: ⚠️ **Requires free registration** at ndi.video
- **URL**: https://ndi.video/for-developers/ndi-sdk/
- **License**: Free for development, commercial license for distribution
- **Steps**:
  1. Go to https://ndi.video/for-developers/ndi-sdk/ in your browser
  2. Register for free NDI developer account
  3. Download "NDI SDK for Linux" (arm64 version)
  4. You'll receive a download link via email (or direct download)
  5. Install:
     ```bash
     # If .tar.gz:
     sudo mkdir -p /opt/ndi-sdk
     sudo tar -xzf ~/Downloads/NDI_SDK_*.tar.gz -C /opt/ndi-sdk --strip-components=1
     
     # If .sh installer:
     chmod +x ~/Downloads/Install_NDI_SDK_*.sh
     sudo ~/Downloads/Install_NDI_SDK_*.sh
     ```
  6. Set up library path:
     ```bash
     echo '/opt/ndi-sdk/lib/aarch64-linux-gnu' | sudo tee /etc/ld.so.conf.d/ndi.conf
     sudo ldconfig
     echo 'export NDI_SDK_DIR=/opt/ndi-sdk' >> ~/.bashrc
     ```
  7. Verify:
     ```bash
     ls /opt/ndi-sdk/include/Processing.NDI.Lib.h
     ls /opt/ndi-sdk/lib/*/libndi.so*
     ```
- **Proot notes**: Library loading works. Network discovery may be limited by proot's network stack; use explicit IP connections.
- **Key headers**: `Processing.NDI.Lib.h`, `Processing.NDI.Find.h`, `Processing.NDI.Send.h`, `Processing.NDI.Recv.h`

---

## What Does NOT Work in Proot

| Tool | Why Not | Alternative |
|------|---------|-------------|
| Docker | Requires kernel namespaces (cgroups, seccomp) | Use Podman rootless (limited) or remote Docker |
| Android Studio | Too heavy, needs HW acceleration, 4GB+ RAM | Use VSCode + Android CLI tools |
| Snap packages | Requires systemd | Use apt or manual install |
| Flatpak | Requires kernel features | Use apt |
| AppImage | Requires FUSE | Extract with `--appimage-extract` |
| Android Emulator | Requires KVM (kernel virtualization) | Use physical device via ADB over network |
| Xcode/iOS builds | macOS only | Use CI/CD (GitHub Actions, Codemagic) |

---

## Disk Space Requirements

| Component | Approximate Size |
|-----------|-----------------|
| VSCode | ~300 MB |
| Chromium | ~200 MB |
| Firefox | ~200 MB |
| Node.js (LTS) | ~80 MB |
| Python 3 + pip | ~100 MB |
| OpenJDK 17 | ~350 MB |
| Android SDK (basic) | ~500 MB |
| Android SDK (full) | ~2-5 GB |
| Gradle | ~150 MB |
| Flutter SDK | ~1.5 GB |
| Rust (rustup) | ~500 MB |
| Go | ~150 MB |
| .NET SDK 8.0 | ~800 MB |
| Build essentials | ~200 MB |
| NDI SDK | ~100 MB |
| Icon themes | ~100-300 MB |
| **Total (everything)** | **~5-10 GB** |

Make sure your proot filesystem has enough space. You can check with:
```bash
df -h /
```

---

## Environment Variables Reference

These are set by the installer in `/etc/environment` and `~/.bashrc`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `ELECTRON_DISABLE_SANDBOX` | `1` | Allow Electron apps in proot (no kernel sandbox) |
| `ELECTRON_DISABLE_GPU` | `1` | Disable GPU process (no hardware GPU in proot) |
| `ELECTRON_DISABLE_SECURITY_WARNINGS` | `1` | Suppress Electron security warnings |
| `LIBGL_ALWAYS_SOFTWARE` | `1` | Force software OpenGL rendering |
| `VSCODE_KEYTAR_USE_BASIC_TEXT_ENCRYPTION` | `1` | Use basic text keyring |
| `NO_AT_BRIDGE` | `1` | Reduce accessibility bridge noise |
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk-arm64` | JDK location |
| `ANDROID_HOME` | `/opt/android-sdk` | Android SDK location |
| `ANDROID_SDK_ROOT` | `/opt/android-sdk` | Android SDK location (legacy var) |
| `NDI_SDK_DIR` | `/opt/ndi-sdk` | NDI SDK location |
| `GOPATH` | `$HOME/go` | Go workspace |
| `DOTNET_ROOT` | `/usr/share/dotnet` | .NET runtime location |
| `NVM_DIR` | `$HOME/.nvm` | nvm installation |

---

## Verification Commands

After installation, verify each component:

```bash
# Core
code --version
chromium --version 2>/dev/null || firefox --version

# SDKs
node --version && npm --version
python3 --version && pip3 --version
java -version
sdkmanager --version
gradle --version
flutter --version
rustc --version && cargo --version
go version
dotnet --version
git --version && gh --version

# NDI
ls /opt/ndi-sdk/include/Processing.NDI.Lib.h

# Environment
echo $ELECTRON_DISABLE_SANDBOX
echo $JAVA_HOME
echo $ANDROID_HOME
```

Or simply run: `sudo bash install.sh` → Option 8 (Validate Installation)
