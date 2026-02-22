# Proot Launcher

Android app to manage your proot development environment with one tap.

## What it does

1. **Start** — Launches Termux → starts proot → starts VNC server → opens VNC viewer
2. **Stop** — Stops VNC server → exits proot → cleans up
3. **Settings** — Configure VNC resolution, display, commands, paths

## Prerequisites

1. **Termux** — Install from [F-Droid](https://f-droid.org/en/packages/com.termux/) (NOT Play Store)
2. **Ubuntu 22.04 proot** — Set up via [Andronix](https://andronix.app/)
3. **AVNC** — VNC viewer from [F-Droid](https://f-droid.org/en/packages/com.gaurav.avnc/) or Play Store

### Termux Configuration

After installing Termux, enable external app control:

```bash
mkdir -p ~/.termux
echo "allow-external-apps=true" >> ~/.termux/termux.properties
```

Restart Termux completely after making this change.

## Building

### From command line (in proot or x64 machine)

```bash
cd proot-launcher
chmod +x gradlew  # if present
./gradlew assembleDebug
```

The APK will be at `app/build/outputs/apk/debug/app-debug.apk`

### From Android Studio

Open the `proot-launcher` directory as a project.

## Architecture

- `MainActivity` — Start/stop buttons, status display
- `SettingsActivity` + `SettingsFragment` — Preference-based settings
- `SetupGuideActivity` — First-time setup instructions
- `TermuxHelper` — Handles Termux RUN_COMMAND intents
- `VncHelper` — Handles VNC viewer detection and launching
- `ProotPreferences` — Typed SharedPreferences wrapper

## VNC Viewer Support

| App | Auto-connect | Recommended |
|-----|:---:|:---:|
| AVNC | ✅ | ✅ |
| bVNC | ✅ | ✅ |
| RealVNC | ❌ | ⚠️ |
| MultiVNC | ✅ | ✅ |

AVNC is recommended because it fully supports `vnc://` URI scheme for programmatic auto-connect.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Proot start script | `./start-ubuntu22.sh` | Path to proot start script |
| VNC display | `:1` | VNC display number |
| VNC resolution | `1920x1080` | Screen resolution |
| VNC start command | `vncserver-start` | Command to start VNC in proot |
| VNC stop command | `vncserver-stop` | Command to stop VNC |
| Auto-connect VNC | `true` | Open VNC viewer after starting |
| Connection delay | `5` seconds | Wait before opening VNC viewer |
| Pre-start command | (empty) | Run before proot starts |
| Post-start command | (empty) | Run after VNC starts |
