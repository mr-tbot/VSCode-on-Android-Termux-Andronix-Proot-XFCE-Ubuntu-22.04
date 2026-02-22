# Proot Development Environment — Comprehensive Project Instructions

## Project Overview

This project creates a **complete mobile development environment** on Android using Termux + Andronix proot (Ubuntu 22.04 XFCE). The goal is seamless portability between your x64 main dev machine and your phone's proot environment, working on the same GitHub projects from either device.

### Components

| Component | Purpose |
|-----------|---------|
| `install.sh` | Interactive installer — each step optional, menu-driven |
| `vscode-proot-chrome-install.sh` | Original standalone fix script (kept for reference) |
| `REQUIREMENTS.md` | SDK/tool requirements with download links & instructions |
| `proot-launcher/` | Android app (APK) to start/stop proot + VNC in one tap |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Android Phone                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  proot-launcher APK                               │  │
│  │  ┌─────────┐  ┌──────────┐  ┌─────────────────┐  │  │
│  │  │  Start   │  │  Stop    │  │  Settings        │  │  │
│  │  │  Proot   │  │  Proot   │  │  VNC port/res    │  │  │
│  │  │  Env     │  │  Env     │  │  Termux paths    │  │  │
│  │  └────┬─────┘  └────┬─────┘  └─────────────────┘  │  │
│  │       │              │                              │  │
│  └───────┼──────────────┼──────────────────────────────┘  │
│          ▼              ▼                                  │
│  ┌──────────────────────────────────────┐                 │
│  │  Termux                              │                 │
│  │  ┌────────────────────────────────┐  │                 │
│  │  │  Proot Ubuntu 22.04 (XFCE)    │  │                 │
│  │  │  ┌──────────┐ ┌────────────┐  │  │                 │
│  │  │  │  VSCode   │ │ Browser    │  │  │                 │
│  │  │  │  (code)   │ │ Chromium/  │  │  │                 │
│  │  │  │           │ │ Firefox    │  │  │                 │
│  │  │  └──────────┘ └────────────┘  │  │                 │
│  │  │  ┌──────────────────────────┐  │  │                 │
│  │  │  │  Dev SDKs               │  │  │                 │
│  │  │  │  Node/Python/Java/      │  │  │                 │
│  │  │  │  Android SDK/Flutter/   │  │  │                 │
│  │  │  │  Gradle/Rust/Go/.NET    │  │  │                 │
│  │  │  └──────────────────────────┘  │  │                 │
│  │  │  ┌──────────┐                  │  │                 │
│  │  │  │ VNC      │◄────────────┐    │  │                 │
│  │  │  │ Server   │             │    │  │                 │
│  │  │  └──────────┘             │    │  │                 │
│  │  └────────────────────────────┘  │                 │
│  └──────────────────────────────────┘                 │
│          ▲                                              │
│          │  vnc://localhost:590X                         │
│  ┌───────┴────────────────────┐                         │
│  │  AVNC / VNC Viewer         │                         │
│  └────────────────────────────┘                         │
└─────────────────────────────────────────────────────────┘
```

---

## Workflow: Moving Between Devices

```
x64 Dev Machine                    Android Phone (proot)
┌──────────────┐    git push/pull   ┌──────────────┐
│  VSCode      │ ◄──────────────► │  VSCode      │
│  Full IDE    │    Same repos     │  proot mode  │
│  All SDKs    │    Same branches  │  Same SDKs   │
│              │                   │              │
│  git push    │ ──────────────► │  git pull    │
│  git pull    │ ◄────────────── │  git push    │
└──────────────┘                   └──────────────┘
```

Both environments have the same SDKs and tools installed. Work is synced via GitHub.

---

## Phase 1: install.sh — Interactive Installer

### Design Principles
1. **Every step is optional** — user picks from a menu
2. **Safe to re-run** — detects what's already done, won't double-install
3. **Must run inside VNC session** — not from raw Termux (user needs browser access for NDI registration, etc.)
4. **Clear progress feedback** — colored output, status messages
5. **Comprehensive error handling** — validates before and after each step

### Menu Structure

```
═══════════════════════════════════════════════════════════
    Proot Development Environment Setup
    Ubuntu 22.04 on Andronix/Termux (arm64)
═══════════════════════════════════════════════════════════

 1) Fix apt sources.list (fix mirrors + remove duplicates)
 2) Install & configure VSCode
 3) Install browser (Chromium / Firefox / Firefox ESR)
 4) Install development SDKs (submenu)
 5) NDI SDK setup (requires browser — guided install)
 6) Fix missing desktop/taskbar icons
 7) Apply proot environment tweaks
 8) Validate installation
 9) Run ALL steps (recommended for fresh installs)
 0) Exit

Choose an option [0-9]:
```

### SDK Submenu (Step 4)

```
═══════════════════════════════════════════════════════════
    Development SDK Installation
═══════════════════════════════════════════════════════════

 a) Node.js (via nvm — LTS)
 b) Python 3 + pip + venv + common packages
 c) Java JDK 17 (OpenJDK)
 d) Android SDK Command-Line Tools
 e) Gradle
 f) Flutter SDK
 g) Rust (via rustup)
 h) Go
 i) .NET SDK 8.0
 j) Git + Git LFS + GitHub CLI
 k) Build essentials (gcc, g++, make, cmake, pkg-config)
 l) Install ALL SDKs
 m) Back to main menu

Choose SDKs to install (comma-separated, e.g. a,b,c):
```

### Step Details

#### Step 1: Fix sources.list
- Replace ftp mirrors with archive.ubuntu.com
- Remove duplicate entries
- Validate with `apt-get update`
- Show error count before/after

#### Step 2: VSCode
- Install from Microsoft apt repo (arm64)
- Create proot wrapper (`--no-sandbox`, etc.)
- Set `password-store=basic` in argv.json
- Install libsecret/gnome-keyring stubs
- Patch .desktop files

#### Step 3: Browser
- **Chromium**: Available via apt for arm64 ✅
- **Google Chrome**: NOT available for arm64 Linux ❌ (inform user)
- **Firefox**: Available via apt or snap (apt preferred in proot) ✅
- **Firefox ESR**: Available via Mozilla PPA ✅
- **None**: Warn that NDI setup and other workflows require a browser
- Selected browser gets proot wrapper + XDG defaults

#### Step 4: Development SDKs
Each SDK install is independent and optional. See REQUIREMENTS.md for full details.

#### Step 5: NDI SDK
- Requires browser to be installed first
- Opens NDI download page (or accepts pasted URL)
- Guides user through registration if needed
- Installs SDK to `/opt/ndi-sdk/`
- Sets up library paths and environment variables

#### Step 6: Icon Fix
- Ask user: "Are desktop/taskbar icons missing or showing as blank?"
- Install `adwaita-icon-theme-full` and/or `papirus-icon-theme`
- Run `gtk-update-icon-cache` and `update-icon-caches`
- Optionally set Papirus as the active icon theme

#### Step 7: Environment Tweaks
- `/etc/environment` variables (GPU disable, sandbox disable, keyring)
- `~/.bashrc` exports
- Electron/Chromium proot-safe defaults
- XDG base directory setup

#### Step 8: Validate
- Check each installed component
- Verify `apt update` runs clean
- Test VSCode launch
- Test browser launch
- Report SDK versions
- Show summary of what's installed vs. missing

---

## Phase 2: REQUIREMENTS.md — SDK Reference

Full documentation of every SDK:
- What it is and why it's needed
- arm64 compatibility status
- Installation method (apt, curl, manual)
- Download URLs
- Post-install configuration
- Verification commands

See [REQUIREMENTS.md](REQUIREMENTS.md) for the complete reference.

---

## Phase 3: proot-launcher Android App

### Purpose
One-tap launch of the entire proot development environment:
1. Start Termux
2. Enter proot environment
3. Start VNC server
4. Connect VNC viewer

One-tap shutdown:
1. Stop VNC server
2. Exit proot
3. (Optionally) close Termux

### Technology
- **Language**: Kotlin
- **Min SDK**: API 24 (Android 7.0)
- **Target SDK**: API 34
- **Build**: Gradle + Kotlin DSL
- **UI**: Material Design 3
- **VNC Viewer**: AVNC (recommended) — supports `vnc://` URI intents

### Why AVNC over RealVNC?
| Feature | AVNC | RealVNC Viewer |
|---------|------|----------------|
| Open source | ✅ Yes (GPL) | ❌ No |
| `vnc://` URI intent | ✅ Yes | ❌ Not reliably |
| Programmatic launch | ✅ Easy | ❌ Difficult |
| F-Droid available | ✅ Yes | ❌ No |
| Play Store | ✅ Yes | ✅ Yes |
| Auto-connect | ✅ Via URI | ❌ Manual only |
| Price | Free | Free (limited) |

### App Screens

#### Main Screen
```
┌─────────────────────────────┐
│  🖥️  Proot Launcher         │
│                             │
│  Status: ● Stopped          │
│                             │
│  ┌───────────────────────┐  │
│  │   ▶  Start Proot Env  │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │   ⏹  Stop Proot Env   │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │   🔗  Open VNC Only   │  │
│  └───────────────────────┘  │
│                             │
│  Last started: 2:34 PM      │
│  VNC: localhost:5901        │
│  Resolution: 1920x1080      │
│                             │
│              ⚙️ Settings     │
└─────────────────────────────┘
```

#### Settings Screen
```
┌─────────────────────────────┐
│  ⚙️  Settings                │
│                             │
│  Termux                     │
│  ├─ Package: com.termux     │
│  │                          │
│  Proot                      │
│  ├─ Start script path:      │
│  │  ~/start-ubuntu22.sh     │
│  ├─ Stop commands:          │
│  │  vncserver-stop          │
│  │                          │
│  VNC Server                 │
│  ├─ Display: :1             │
│  ├─ Port: 5901              │
│  ├─ Resolution: 1920x1080   │
│  ├─ Start cmd:              │
│  │  vncserver-start         │
│  ├─ Stop cmd:               │
│  │  vncserver-stop          │
│  │                          │
│  VNC Viewer                 │
│  ├─ App: AVNC               │
│  ├─ Auto-connect: ✅         │
│  ├─ Connection delay: 5s    │
│  │                          │
│  Advanced                   │
│  ├─ Custom env vars         │
│  ├─ Pre-start commands      │
│  ├─ Post-start commands     │
│                             │
│         [Save] [Reset]      │
└─────────────────────────────┘
```

### App Workflow

```
User taps "Start Proot Env"
         │
         ▼
  Launch Termux via intent
  (com.termux.RUN_COMMAND)
         │
         ▼
  Execute proot start script
  (e.g., ./start-ubuntu22.sh)
         │
         ▼
  Inside proot: run vncserver-start
  with configured resolution
         │
         ▼
  Wait configured delay (default 5s)
         │
         ▼
  Launch AVNC via vnc:// URI intent
  vnc://localhost:{port}
         │
         ▼
  Status: ● Running
```

### Termux Integration
The app uses Termux's `RUN_COMMAND` intent (requires Termux:Tasker add-on or
enabling `allow-external-apps=true` in `~/.termux/termux.properties`):

```kotlin
val intent = Intent("com.termux.RUN_COMMAND").apply {
    setClassName("com.termux", "com.termux.app.RunCommandService")
    putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
    putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", startScript))
    putExtra("com.termux.RUN_COMMAND_BACKGROUND", false)
}
```

### VNC Viewer Launch
```kotlin
// AVNC supports vnc:// URI scheme
val uri = Uri.parse("vnc://localhost:$vncPort")
val intent = Intent(Intent.ACTION_VIEW, uri)
startActivity(intent)
```

---

## Prerequisites

Before running `install.sh`, ensure:

1. **Termux** is installed from F-Droid (NOT Play Store — the Play Store version is outdated)
2. **Andronix** has set up Ubuntu 22.04 with XFCE desktop
3. The proot environment boots and you can access it
4. A VNC server/viewer setup is working (even if basic)
5. You are running the installer **inside the VNC session** (not raw Termux)

### Termux Setup (if not done)
```bash
# In Termux (not proot)
pkg update && pkg upgrade
pkg install x11-repo
pkg install tigervnc
```

### Proot Start Script
Your proot start script (often `start-ubuntu22.sh` or similar) should be in your Termux home directory. The proot-launcher app will need to know its path.

---

## File Structure

```
.
├── README.md                          # Project overview
├── instructions.md                    # This file — comprehensive guide
├── REQUIREMENTS.md                    # SDK requirements & download links
├── install.sh                         # Interactive installer (main script)
├── vscode-proot-chrome-install.sh     # Original standalone script (reference)
│
└── proot-launcher/                    # Android app source
    ├── app/
    │   ├── build.gradle.kts
    │   └── src/
    │       └── main/
    │           ├── AndroidManifest.xml
    │           ├── java/com/prootlauncher/
    │           │   ├── MainActivity.kt
    │           │   ├── SettingsActivity.kt
    │           │   ├── TermuxHelper.kt
    │           │   └── VncHelper.kt
    │           └── res/
    │               ├── layout/
    │               │   ├── activity_main.xml
    │               │   └── activity_settings.xml
    │               ├── values/
    │               │   ├── strings.xml
    │               │   ├── colors.xml
    │               │   └── themes.xml
    │               └── xml/
    │                   └── preferences.xml
    ├── build.gradle.kts
    ├── settings.gradle.kts
    └── gradle.properties
```

---

## Development Workflow

### On x64 Machine (main dev)
1. Work normally in VSCode / IDE of choice
2. `git commit && git push` when done

### On Android Phone (proot)
1. Open **proot-launcher** app → tap **Start Proot Env**
2. VNC viewer opens automatically
3. Open terminal in XFCE → `cd ~/projects/your-repo && git pull`
4. Open VSCode: `code .`
5. Work, commit, push
6. When done → open **proot-launcher** → tap **Stop Proot Env**

### Shared Configuration
- `.gitignore` — same across both environments
- `.vscode/settings.json` — use platform-independent paths
- Use `nvm` for Node.js version consistency
- Use `venv` for Python virtual environments
- Store secrets in environment variables, not committed files

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| VSCode crashes on launch | Run `code --verbose --no-sandbox` to see errors |
| Keyring popup appears | Cancel it — `password-store=basic` handles auth |
| Icons missing in XFCE | Run install.sh → option 6 (Fix icons) |
| `apt update` shows errors | Run install.sh → option 1 (Fix sources.list) |
| Browser won't open links | Check XDG defaults — run install.sh → option 3 |
| VNC black screen | Restart VNC: `vncserver-stop && vncserver-start` |  
| "SUID sandbox helper" error | Normal proot noise — harmless |
| Electron "namespace" warning | Normal proot noise — harmless |
| NDI SDK download needs login | Use browser inside VNC session for registration |
| `npm install` fails with EACCES | Don't use sudo with nvm-installed Node |
| Gradle OOM in proot | Set `org.gradle.jvmargs=-Xmx512m` in gradle.properties |
| Flutter doctor warnings | Expected — no Chrome/Android Studio in proot, use CLI |

### Harmless Proot Warnings (ignore these)
```
Failed to move to new namespace: PID namespaces supported, ...
dbus / netlink / udev / inotify warnings
SUID sandbox helper binary not found
Received signal 11 (rare, retry launch)
libGL error: failed to open /dev/dri/...
```

---

## Feature Suggestions & Roadmap

### Implemented
- [x] Interactive installer with optional steps
- [x] Multiple browser support
- [x] SDK installation suite
- [x] NDI guided setup
- [x] Icon fix utility
- [x] proot-launcher Android app
- [x] Environment validation

### Future Enhancements
- [ ] **Backup/Restore**: Export proot config + installed packages list for quick re-setup
- [ ] **dotfiles sync**: Auto-sync shell config, VSCode settings via GitHub dotfiles repo
- [ ] **Termux:Widget integration**: Home screen shortcuts for common dev commands
- [ ] **SSH server in proot**: Enable remote access from other devices on same network
- [ ] **Watchman/file sync**: Auto-sync specific folders between environments
- [ ] **CI/CD integration**: Run GitHub Actions locally with `act` (limited in proot)
- [ ] **Tailscale/ZeroTier**: Secure network between phone and dev machine
- [ ] **Code Server**: Web-based VSCode as alternative to VNC for lighter workloads
- [ ] **Battery optimization**: Auto-stop VNC after idle timeout
- [ ] **proot-launcher widget**: Android home screen widget showing env status

---

## Notes

### What Works in Proot
- VSCode (with `--no-sandbox`)
- Chromium / Firefox (with `--no-sandbox`)
- Node.js, Python, Java, Go, Rust, .NET
- Android SDK command-line tools (aapt2, d8, signing)
- Gradle builds
- Flutter CLI builds
- Git, SSH, GPG
- Most CLI dev tools

### What Does NOT Work in Proot
- Docker (requires kernel namespaces)
- Android Studio (too heavy, needs HW acceleration)
- Snap packages (requires systemd)
- Flatpak (requires kernel features)
- AppImage (requires FUSE)
- Hardware GPU acceleration
- Anything requiring actual kernel syscall support (seccomp, namespaces, cgroups)

### Performance Tips
- Close browser tabs you're not using — RAM is limited on phones
- Use `--max-old-space-size=512` for Node.js heavy builds
- Set Gradle JVM args: `-Xmx512m -XX:MaxMetaspaceSize=256m`
- Use `code --disable-extensions` if VSCode is sluggish
- Consider lighter alternatives: `nano`/`vim` for quick edits, `lite-xl` for lighter GUI editor
