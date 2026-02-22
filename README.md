# Proot Dev Environment — Android + Termux + Ubuntu 22.04

A comprehensive toolkit for running a **full development environment** on Android via Termux/Andronix proot (Ubuntu 22.04 + XFCE). Enables portable development across your x64 machine and Android phone, working on the same GitHub projects from either device.

## What's Included

| File | Description |
|------|-------------|
| [`install.sh`](install.sh) | **Interactive installer** — menu-driven, every step optional, safe to re-run |
| [`REQUIREMENTS.md`](REQUIREMENTS.md) | SDK requirements, download links, compatibility matrix |
| [`instructions.md`](instructions.md) | Comprehensive project guide and architecture docs |
| [`vscode-proot-chrome-install.sh`](vscode-proot-chrome-install.sh) | Original standalone fix script (kept for reference) |
| [`proot-launcher/`](proot-launcher/) | **Android app** — one-tap start/stop proot + VNC |

## Quick Start

```bash
# Inside your VNC session (not raw Termux):
sudo bash install.sh
```

The interactive menu lets you:

1. **Fix apt sources.list** — replace ftp mirrors, remove duplicates
2. **Install VSCode** — with proot wrappers, keyring fixes, .desktop patches
3. **Install a browser** — Chromium, Firefox, or Firefox ESR (Google Chrome is NOT available for arm64)
4. **Install dev SDKs** — Node.js, Python, Java, Android SDK, Gradle, Flutter, Rust, Go, .NET, Git+GH CLI
5. **NDI SDK setup** — guided registration + install (requires browser)
6. **Fix missing icons** — Adwaita / Papirus icon theme installation
7. **Proot env tweaks** — Electron/Chromium sandbox/GPU/keyring environment variables
8. **Validate** — check everything is installed and working

## Proot Launcher App

The [`proot-launcher/`](proot-launcher/) directory contains a Kotlin Android app that provides:

- **One-tap start**: Launches Termux → starts proot → starts VNC → opens AVNC viewer
- **One-tap stop**: Cleanly shuts down VNC and proot
- **Configurable settings**: VNC display, resolution, port, commands, delays
- **Setup guide**: Built-in first-time setup instructions

Recommended VNC viewer: **[AVNC](https://f-droid.org/en/packages/com.gaurav.avnc/)** (open source, supports `vnc://` auto-connect URIs)

## Architecture

```
Android Phone
├── proot-launcher (APK)  →  One-tap start/stop
├── Termux                →  Terminal emulator
│   └── Proot Ubuntu 22.04 (XFCE)
│       ├── VSCode        →  Code editor
│       ├── Browser       →  Chromium/Firefox
│       ├── Dev SDKs      →  Node/Python/Java/Android/Flutter/Rust/Go/.NET
│       └── VNC Server    →  Desktop access
└── AVNC                  →  VNC viewer (auto-launched)
```

## Requirements

- **Android phone** with Termux (from F-Droid, not Play Store)
- **Andronix** — Ubuntu 22.04 with XFCE desktop
- **AVNC** or other VNC viewer
- **~5-10 GB** free space for all SDKs (individual installs are smaller)

## Documentation

- [instructions.md](instructions.md) — Full project guide, architecture, troubleshooting
- [REQUIREMENTS.md](REQUIREMENTS.md) — Detailed SDK reference with install commands
- [proot-launcher/README.md](proot-launcher/README.md) — Android app documentation
