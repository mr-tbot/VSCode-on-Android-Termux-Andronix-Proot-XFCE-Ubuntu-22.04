# VSCode on Android - Termux/Andronix Proot Setup

A simple toolkit aimed at performing various fixes (chromium, repos, helpers) in order to start and run VSCode in a proot environment such as Termux (using Andronix Ubuntu 22.04 with XFCE) - Allowing for true remote dev work in VSCode!

## Overview

This repository provides a comprehensive setup script that configures Visual Studio Code to run properly in Android proot environments (Termux/Andronix). The script addresses common issues like Chrome sandboxing, repository configuration, and environment setup.

## Features

- ✅ **Chrome Sandbox Fix**: Disables Electron sandboxing (required for proot)
- ✅ **Repository Configuration**: Fixes apt sources and package management
- ✅ **Dependency Installation**: Installs all required libraries for VSCode
- ✅ **VSCode Installation**: Downloads and installs VSCode from official Microsoft repository
- ✅ **Helper Scripts**: Provides utilities for troubleshooting and maintenance
- ✅ **Environment Setup**: Configures proper environment variables
- ✅ **Easy Launcher**: Creates convenient launcher script with correct flags

## Requirements

- Android device with Termux installed
- Andronix Ubuntu 22.04 (or similar proot Linux distribution)
- XFCE desktop environment
- At least 2GB of free storage space
- Active internet connection

## Installation

### Quick Start

1. **Clone this repository:**
```bash
git clone https://github.com/mr-tbot/VSCode-on-Android-Termux-Andronix-Proot-XFCE-Ubuntu-22.04.git
cd VSCode-on-Android-Termux-Andronix-Proot-XFCE-Ubuntu-22.04
```

2. **Run the setup script as root:**
```bash
sudo bash setup-vscode.sh
```

3. **Start XFCE (if not already running):**
```bash
startxfce4
```

4. **Launch VSCode:**
```bash
vscode-launcher
```

## What the Script Does

The setup script performs the following operations:

1. **Environment Check**: Verifies you're running in a proot environment
2. **Repository Fix**: Updates and repairs apt sources if needed
3. **Dependency Installation**: Installs required libraries:
   - Core utilities (wget, curl, git)
   - Graphics libraries (libgtk-3-0, libdrm2, libgbm1)
   - Audio libraries (libasound2)
   - Security libraries (libnss3, ca-certificates)
   - And many more...
4. **Chrome Sandbox Fix**: Disables sandboxing for Electron/Chrome
   - Sets `ELECTRON_NO_SANDBOX=1`
   - Sets `CHROME_NO_SANDBOX=1`
   - Creates system-wide configuration
5. **VSCode Installation**: Downloads and installs VSCode from Microsoft repository
6. **Launcher Creation**: Creates `/usr/local/bin/vscode-launcher` with proper flags
7. **Helper Scripts**: Creates utility scripts in `/opt/vscode-helpers/`:
   - `check-env.sh`: Verify environment configuration
   - `fix-permissions.sh`: Fix common permission issues

## Usage

### Launching VSCode

After installation, you have two options:

**Option 1 - Using the launcher (recommended):**
```bash
vscode-launcher
```

**Option 2 - Direct command:**
```bash
code --no-sandbox
```

### Helper Commands

**Check environment configuration:**
```bash
/opt/vscode-helpers/check-env.sh
```

**Fix permission issues:**
```bash
/opt/vscode-helpers/fix-permissions.sh
```

**View usage instructions:**
```bash
cat /opt/vscode-helpers/README.txt
```

## Troubleshooting

### VSCode won't start

1. **Check if DISPLAY is set:**
```bash
echo $DISPLAY
```
If not set, start your X server first:
```bash
startxfce4
```

2. **Verify X server is running:**
```bash
ps aux | grep X
```

3. **Run environment check:**
```bash
/opt/vscode-helpers/check-env.sh
```

4. **Fix permissions:**
```bash
/opt/vscode-helpers/fix-permissions.sh
```

5. **Try with verbose output:**
```bash
code --no-sandbox --verbose
```

### Common Issues

**Issue: "GPU process isn't usable. Goodbye."**
- Solution: This is normal in proot. The script sets `LIBGL_ALWAYS_SOFTWARE=1` to use software rendering.

**Issue: "Running as root without --no-sandbox is not supported"**
- Solution: Use the `vscode-launcher` script or always include the `--no-sandbox` flag.

**Issue: Extensions won't install**
- Solution: Some extensions may not work in proot. Try using alternative extensions or running in limited mode.

**Issue: "Cannot find module" errors**
- Solution: Run `sudo apt-get install --fix-broken` and try again.

## Architecture

The setup consists of:

```
├── setup-vscode.sh              # Main setup script
├── /usr/local/bin/
│   ├── chrome-no-sandbox.sh     # Chrome sandbox disabler
│   └── vscode-launcher          # VSCode launcher script
└── /opt/vscode-helpers/
    ├── check-env.sh             # Environment checker
    ├── fix-permissions.sh       # Permission fixer
    └── README.txt               # User documentation
```

## Technical Details

### Chrome Sandbox

VSCode uses Electron, which relies on Chromium. Chromium's sandbox requires kernel features not available in proot environments. The script disables sandboxing by:
- Setting environment variables (`ELECTRON_NO_SANDBOX`, `CHROME_NO_SANDBOX`)
- Passing `--no-sandbox` flag to VSCode/Electron
- Adding these settings to system-wide profile

### Software Rendering

Hardware GPU acceleration doesn't work reliably in proot. The script enables software rendering with `LIBGL_ALWAYS_SOFTWARE=1`.

### Dependencies

VSCode requires numerous libraries. The script installs all of them, including:
- GTK+ 3 for UI rendering
- NSS libraries for security
- ALSA for audio
- X11 libraries for display

## Limitations

- Hardware acceleration is disabled (software rendering only)
- Some VSCode extensions may not work properly
- Performance may be slower than native VSCode
- Debugger support may be limited
- Some language servers might have issues

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is provided as-is for educational and development purposes.

## Credits

Created for the Android development community using Termux and Andronix.

## Related Resources

- [Termux](https://termux.com/)
- [Andronix](https://andronix.app/)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Proot](https://proot-me.github.io/)

## Support

If you encounter issues:
1. Run `/opt/vscode-helpers/check-env.sh`
2. Check the troubleshooting section above
3. Open an issue on GitHub with detailed information

---

**Enjoy coding on your Android device! 📱💻**
