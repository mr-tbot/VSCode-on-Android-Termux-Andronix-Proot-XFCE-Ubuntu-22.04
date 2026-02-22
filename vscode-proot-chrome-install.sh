
#!/usr/bin/env bash
# proot-xfce-chromium-vscode-fix.sh
#
# Applies Chromium + VSCode proot/XFCE fixes for Ubuntu 22.04 running inside
# Andronix/Termux proot on Android.
#
# What it does:
#  CHROMIUM
#  1) Wraps /usr/bin/chromium so ANY caller (exo-open, xfce4-mime-helper, etc.)
#     gets the required proot-safe flags (--no-sandbox etc.).
#  2) [opt] Patches /usr/share/applications/chromium.desktop Exec= line.
#  3) [opt] Sets XDG defaults for http/https/text/html to chromium.desktop.
#  4) [opt] Installs at-spi2-core to reduce AT-SPI warning spam.
#
#  VSCODE
#  5) Installs VSCode via the official Microsoft apt repository.
#  6) Wraps /usr/bin/code so it always launches with --no-sandbox and other
#     proot-safe Electron flags.
#  7) Writes /root/.config/Code/argv.json with password-store=basic to
#     suppress gnome-keyring / libsecret errors entirely.
#  8) [opt] Patches /usr/share/applications/code.desktop Exec= lines.
#  9) Installs libsecret-1-0 / gnome-keyring stubs (best-effort) so VSCode
#     does not crash looking for them even though we use basic store.
#
# PROOT-GENERAL
# 10) Writes /etc/environment additions that suppress common Electron/
#     Chromium noise in proot (no GPU, no SUID sandbox, basic keyring).
# 11) Adds ELECTRON_DISABLE_SANDBOX=1 export to ~/.bashrc.
#
# SOURCES.LIST
#  0) Replaces ftp.*.ubuntu.com mirror URLs with archive.ubuntu.com (more
#     reliable in proot/container environments where FTP is often blocked).
#     Also comments out any duplicate deb/deb-src lines, keeping the first
#     occurrence, to prevent apt warnings about redundant sources.
#
# Usage:
#   sudo bash proot-xfce-chromium-vscode-fix.sh              # recommended
#   sudo bash proot-xfce-chromium-vscode-fix.sh --no-apt     # skip ALL apt steps
#   sudo bash proot-xfce-chromium-vscode-fix.sh --no-xdg     # skip XDG mime defaults
#   sudo bash proot-xfce-chromium-vscode-fix.sh --no-vscode  # skip VSCode install/wrap
#   sudo bash proot-xfce-chromium-vscode-fix.sh --patch-desktop   # patch .desktop Exec= lines
#   sudo bash proot-xfce-chromium-vscode-fix.sh --with-atspi      # install at-spi2-core
#
# Flags may be combined freely.
#
# Notes:
#  - Safe to re-run: backups are created once and will not double-wrap.
#  - Designed for proot where all processes run as root (UID 0) and kernel
#    namespaces / seccomp sandboxes are unavailable.
#  - Normal proot noise (dbus/netlink/udev/inotify) is NOT silenced here;
#    those are cosmetic warnings from the proot kernel shim.
#
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
NO_APT=0
NO_XDG=0
NO_VSCODE=0
PATCH_DESKTOP=0
WITH_ATSPI=0

for arg in "$@"; do
  case "$arg" in
    --no-apt)        NO_APT=1 ;;
    --no-xdg)        NO_XDG=1 ;;
    --no-vscode)     NO_VSCODE=1 ;;
    --patch-desktop) PATCH_DESKTOP=1 ;;
    --with-atspi)    WITH_ATSPI=1 ;;
    -h|--help)
      sed -n '1,60p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: run as root inside the proot environment."
    echo "Try:  sudo bash $0  $*"
    exit 1
  fi
}

msg()  { printf '\n[*] %s\n' "$*"; }
ok()   { printf '    OK: %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }

need_root

# ── Section 0: Fix /etc/apt/sources.list ─────────────────────────────────────
msg "Section 0 — Fixing /etc/apt/sources.list (ftp mirrors → archive, duplicates)"

SOURCES=/etc/apt/sources.list
if [[ -f "$SOURCES" ]]; then
  # Backup once
  [[ ! -f "${SOURCES}.bak.prootfix" ]] && cp -v "$SOURCES" "${SOURCES}.bak.prootfix"

  # 1) Replace ftp.*.ubuntu.com (and bare ftp.ubuntu.com) with archive.ubuntu.com
  if grep -qE 'ftp[^[:space:]]*\.ubuntu\.com' "$SOURCES"; then
    sed -i -E 's|ftp[^[:space:]]*\.ubuntu\.com|archive.ubuntu.com|g' "$SOURCES"
    ok "Replaced ftp mirror URL(s) with archive.ubuntu.com"
  else
    ok "No ftp mirror URLs found in $SOURCES – nothing to replace."
  fi

  # 2) Comment out duplicate deb/deb-src lines, keeping the first occurrence
  BEFORE=$(grep -cE '^[[:space:]]*deb' "$SOURCES" 2>/dev/null || true)
  TMP=$(mktemp)
  awk '
    /^[[:space:]]*$/  { print; next }
    /^[[:space:]]*#/  { print; next }
    !seen[$0]++        { print; next }
                       { print "# [duplicate removed] " $0 }
  ' "$SOURCES" > "$TMP" && mv "$TMP" "$SOURCES"
  AFTER=$(grep -cE '^[[:space:]]*deb' "$SOURCES" 2>/dev/null || true)
  REMOVED=$(( BEFORE - AFTER ))
  if [[ "$REMOVED" -gt 0 ]]; then
    ok "Commented out $REMOVED duplicate deb/deb-src line(s) in $SOURCES"
  else
    ok "No duplicate deb/deb-src lines found in $SOURCES."
  fi
else
  warn "$SOURCES not found – skipping sources.list fixes."
fi

# ── Section 1: Chromium wrapper ───────────────────────────────────────────────
msg "Section 1 — Chromium proot wrapper"

if [[ ! -e /usr/bin/chromium ]]; then
  warn "/usr/bin/chromium not found – skipping Chromium wrapper."
else
  if [[ ! -x /usr/bin/chromium ]]; then
    warn "/usr/bin/chromium exists but is not executable. Fixing..."
    chmod +x /usr/bin/chromium || true
  fi

  if head -n 5 /usr/bin/chromium 2>/dev/null | grep -q "chromium.real"; then
    ok "/usr/bin/chromium already wrapped (chromium.real found in header)."
  else
    if [[ ! -f /usr/bin/chromium.real ]]; then
      msg "Backing up /usr/bin/chromium -> /usr/bin/chromium.real"
      cp -v /usr/bin/chromium /usr/bin/chromium.real
    else
      ok "Backup /usr/bin/chromium.real already exists (not overwriting)."
    fi

    cat > /usr/bin/chromium <<'CHROMIUM_WRAPPER'
#!/bin/sh
# proot Chromium wrapper – installed by proot-xfce-chromium-vscode-fix.sh
# XFCE/exo-open launches /usr/bin/chromium with only the URL and no flags.
# Root in proot requires --no-sandbox; GPU is unavailable.
exec /usr/bin/chromium.real \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --no-zygote \
  "$@"
CHROMIUM_WRAPPER
    chmod +x /usr/bin/chromium
    ok "Chromium wrapper installed at /usr/bin/chromium"
  fi
fi

# ── Section 2: Patch chromium.desktop (optional) ──────────────────────────────
if [[ "$PATCH_DESKTOP" -eq 1 ]]; then
  msg "Section 2 — Patching chromium.desktop"
  if [[ -f /usr/share/applications/chromium.desktop ]]; then
    [[ ! -f /usr/share/applications/chromium.desktop.bak.prootfix ]] && \
      cp -v /usr/share/applications/chromium.desktop \
            /usr/share/applications/chromium.desktop.bak.prootfix
    sed -i 's|^Exec=.*|Exec=/usr/bin/chromium %U|' \
      /usr/share/applications/chromium.desktop || true
    ok "chromium.desktop Exec= lines patched."
  else
    warn "/usr/share/applications/chromium.desktop not found; skipping."
  fi
fi

# ── Section 3: XDG defaults for Chromium (optional) ──────────────────────────
if [[ "$NO_XDG" -eq 0 ]]; then
  msg "Section 3 — Setting XDG web-browser defaults to chromium.desktop"
  set +e
  command -v xdg-settings >/dev/null 2>&1 && \
    xdg-settings set default-web-browser chromium.desktop
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default chromium.desktop x-scheme-handler/http
    xdg-mime default chromium.desktop x-scheme-handler/https
    xdg-mime default chromium.desktop text/html
  fi
  set -e
  ok "XDG web defaults configured."
else
  msg "Section 3 — Skipping XDG defaults (--no-xdg)"
fi

# ── Section 4: at-spi2-core (optional) ───────────────────────────────────────
if [[ "$WITH_ATSPI" -eq 1 ]]; then
  msg "Section 4 — Installing at-spi2-core (reduces AT-SPI warning spam)"
  if [[ "$NO_APT" -eq 1 ]]; then
    warn "Skipping apt install of at-spi2-core (--no-apt)"
  else
    set +e
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y at-spi2-core >/dev/null 2>&1
    set -e
    ok "at-spi2-core installed (or already present)."
  fi
fi

# ── Section 5: Install VSCode ─────────────────────────────────────────────────
if [[ "$NO_VSCODE" -eq 1 ]]; then
  msg "Section 5 — Skipping VSCode install (--no-vscode)"
else
  msg "Section 5 — Installing Visual Studio Code"

  if command -v code >/dev/null 2>&1; then
    ok "VSCode (code) is already in PATH; skipping install."
  else
    if [[ "$NO_APT" -eq 1 ]]; then
      warn "VSCode is not installed and --no-apt was given. Skipping install."
      warn "Run without --no-apt, or install manually and re-run this script."
    else
      # Detect architecture (Termux proot is typically aarch64)
      ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
      case "$ARCH" in
        amd64|x86_64)   VSCODE_ARCH="amd64" ;;
        arm64|aarch64)  VSCODE_ARCH="arm64" ;;
        armhf|armv7*)   VSCODE_ARCH="armhf" ;;
        *)
          warn "Unknown architecture '$ARCH'. Defaulting to amd64 for VSCode repo."
          VSCODE_ARCH="amd64"
          ;;
      esac

      msg "  Detected architecture: $ARCH -> using VSCode repo arch: $VSCODE_ARCH"

      # Add Microsoft GPG key
      if [[ ! -f /usr/share/keyrings/microsoft-archive-keyring.gpg ]]; then
        msg "  Adding Microsoft GPG key..."
        set +e
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
          | gpg --dearmor \
          > /usr/share/keyrings/microsoft-archive-keyring.gpg
        set -e
        ok "Microsoft GPG key added."
      else
        ok "Microsoft GPG key already present."
      fi

      # Add VSCode apt repo
      VSCODE_LIST=/etc/apt/sources.list.d/vscode.list
      if [[ ! -f "$VSCODE_LIST" ]]; then
        echo "deb [arch=${VSCODE_ARCH} signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] \
https://packages.microsoft.com/repos/code stable main" \
          > "$VSCODE_LIST"
        ok "VSCode apt repository added."
      else
        ok "VSCode apt repository already configured."
      fi

      # Install dependencies and VSCode
      msg "  Running apt-get update & install..."
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        libsecret-1-0 \
        libgbm1 \
        libasound2 \
        code
      ok "VSCode installed."
    fi
  fi
fi

# ── Section 6: VSCode wrapper (/usr/bin/code) ─────────────────────────────────
if [[ "$NO_VSCODE" -eq 0 ]]; then
  msg "Section 6 — VSCode proot wrapper"

  if ! command -v code >/dev/null 2>&1 && [[ ! -e /usr/bin/code ]]; then
    warn "/usr/bin/code not found; skipping wrapper (VSCode not installed)."
  else
    CODE_BIN="/usr/bin/code"

    # Determine if already our wrapper
    already_wrapped_code=0
    if head -n 6 "$CODE_BIN" 2>/dev/null | grep -q "code\.real\|proot VSCode wrapper"; then
      already_wrapped_code=1
    fi

    if [[ "$already_wrapped_code" -eq 1 ]]; then
      ok "/usr/bin/code already wrapped."
    else
      # /usr/bin/code is typically a symlink -> /usr/share/code/bin/code (a shell script).
      # We resolve the real target, leave it untouched, and replace the symlink
      # with our own wrapper that prepends the necessary flags.
      if [[ -L "$CODE_BIN" ]]; then
        CODE_REAL_TARGET="$(readlink -f "$CODE_BIN")"
        msg "  /usr/bin/code is a symlink -> $CODE_REAL_TARGET"
        rm -f "$CODE_BIN"
        ok "  Symlink removed; will create wrapper in its place."
      else
        # It's a plain file – rename it
        if [[ ! -f /usr/bin/code.real ]]; then
          cp -v "$CODE_BIN" /usr/bin/code.real
        else
          ok "  Backup /usr/bin/code.real already exists (not overwriting)."
        fi
        CODE_REAL_TARGET="/usr/bin/code.real"
        rm -f "$CODE_BIN"
      fi

      # Write wrapper
      cat > /usr/bin/code <<VSCODE_WRAPPER
#!/bin/sh
# proot VSCode wrapper – installed by proot-xfce-chromium-vscode-fix.sh
# Running as root in proot requires --no-sandbox.
# --password-store=basic prevents libsecret/gnome-keyring lookup errors.
exec "${CODE_REAL_TARGET}" \\
  --no-sandbox \\
  --disable-gpu \\
  --disable-dev-shm-usage \\
  --disable-software-rasterizer \\
  --password-store=basic \\
  "\$@"
VSCODE_WRAPPER
      chmod +x /usr/bin/code
      ok "VSCode wrapper installed at /usr/bin/code (calls $CODE_REAL_TARGET)"
    fi
  fi
fi

# ── Section 7: VSCode argv.json – password-store=basic ───────────────────────
if [[ "$NO_VSCODE" -eq 0 ]]; then
  msg "Section 7 — Writing VSCode argv.json (password-store=basic)"

  # Apply for root (always the active user in proot) and any real user
  # found under /home as a best-effort pass.
  write_argv_json() {
    local cfg_dir="$1/Code"
    mkdir -p "$cfg_dir"
    local argv="$cfg_dir/argv.json"
    if [[ -f "$argv" ]]; then
      # Merge: set/overwrite password-store key without destroying other settings
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$argv" <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except Exception:
    data = {}
data["password-store"] = "basic"
# Also suppress crash-reporter and telemetry noise common in proot
data.setdefault("enable-crash-reporter", False)
p.write_text(json.dumps(data, indent=4) + "\n")
print(f"    Merged: {p}")
PYEOF
      else
        # python3 not available – write a safe minimal file if none exists
        if ! grep -q '"password-store"' "$argv" 2>/dev/null; then
          cp "$argv" "${argv}.bak.prootfix" 2>/dev/null || true
          printf '{\n    "password-store": "basic",\n    "enable-crash-reporter": false\n}\n' \
            > "$argv"
          ok "  Written minimal argv.json at $argv"
        else
          ok "  password-store already set in $argv"
        fi
      fi
    else
      printf '{\n    "password-store": "basic",\n    "enable-crash-reporter": false\n}\n' \
        > "$argv"
      ok "  Created $argv"
    fi
  }

  write_argv_json "/root/.config"

  # Also cover any non-root users that may have been created
  for home_dir in /home/*/; do
    [[ -d "$home_dir" ]] || continue
    user_cfg="$home_dir/.config"
    write_argv_json "$user_cfg"
  done
fi

# ── Section 7b: VSCode settings.json – proot-friendly defaults ───────────────
if [[ "$NO_VSCODE" -eq 0 ]]; then
  msg "Section 7b — Writing VSCode user settings (diffEditor, Copilot)"

  write_vscode_settings() {
    local cfg_dir="$1/Code/User"
    mkdir -p "$cfg_dir"
    local settings="$cfg_dir/settings.json"
    if [[ -f "$settings" ]]; then
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$settings" <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except Exception:
    data = {}
data["diffEditor.maxComputationTime"] = 0
data["github.copilot.chat.tools.autoApprove"] = True
p.write_text(json.dumps(data, indent=4) + "\n")
print(f"    Merged: {p}")
PYEOF
      else
        local changed=0
        if ! grep -q 'diffEditor.maxComputationTime' "$settings" 2>/dev/null; then
          cp "$settings" "${settings}.bak.prootfix" 2>/dev/null || true
          sed -i 's/}$/,\n    "diffEditor.maxComputationTime": 0\n}/' "$settings" 2>/dev/null || true
          changed=1
        fi
        if ! grep -q 'github.copilot.chat.tools.autoApprove' "$settings" 2>/dev/null; then
          sed -i 's/}$/,\n    "github.copilot.chat.tools.autoApprove": true\n}/' "$settings" 2>/dev/null || true
          changed=1
        fi
        if [[ "$changed" -eq 1 ]]; then
          ok "  Updated settings in $settings"
        else
          ok "  Settings already configured in $settings"
        fi
      fi
    else
      printf '{\n    "diffEditor.maxComputationTime": 0,\n    "github.copilot.chat.tools.autoApprove": true\n}\n' \
        > "$settings"
      ok "  Created $settings"
    fi
  }

  write_vscode_settings "/root/.config"

  for home_dir in /home/*/; do
    [[ -d "$home_dir" ]] || continue
    user_cfg="$home_dir/.config"
    write_vscode_settings "$user_cfg"
  done
fi

# ── Section 8: Patch code.desktop (optional) ─────────────────────────────────
if [[ "$PATCH_DESKTOP" -eq 1 && "$NO_VSCODE" -eq 0 ]]; then
  msg "Section 8 — Patching code.desktop"
  CODE_DESKTOP=/usr/share/applications/code.desktop
  if [[ -f "$CODE_DESKTOP" ]]; then
    [[ ! -f "${CODE_DESKTOP}.bak.prootfix" ]] && \
      cp -v "$CODE_DESKTOP" "${CODE_DESKTOP}.bak.prootfix"
    # Replace all Exec= lines (there are typically two: one with %F, one %U)
    sed -i 's|^Exec=/usr/share/code/code\b|Exec=/usr/bin/code|g' "$CODE_DESKTOP" || true
    sed -i 's|^Exec=code\b|Exec=/usr/bin/code|g'                  "$CODE_DESKTOP" || true
    ok "code.desktop Exec= lines updated to call /usr/bin/code (wrapper)."
    grep '^Exec=' "$CODE_DESKTOP" || true
  else
    warn "code.desktop not found at $CODE_DESKTOP; skipping."
  fi
fi

# ── Section 9: /etc/environment – proot Electron/Chromium env defaults ────────
msg "Section 9 — Updating /etc/environment with proot-safe Electron/Chromium vars"

add_env_var() {
  local var="$1"
  local val="$2"
  local line="${var}=${val}"
  if grep -q "^${var}=" /etc/environment 2>/dev/null; then
    # Already present – overwrite the line
    sed -i "s|^${var}=.*|${line}|" /etc/environment
    ok "  Updated: $line"
  else
    echo "$line" >> /etc/environment
    ok "  Added:   $line"
  fi
}

# Prevent Electron apps from trying the GPU process (no GPU in proot)
add_env_var "LIBGL_ALWAYS_SOFTWARE" "1"

# Tell Electron/Chromium: no hardware GPU
add_env_var "ELECTRON_DISABLE_GPU" "1"

# Suppress Electron security warnings printed to terminal (cosmetic)
add_env_var "ELECTRON_DISABLE_SECURITY_WARNINGS" "1"

# Make Electron use the basic secret store globally (belt-and-suspenders
# alongside argv.json and the --password-store=basic wrapper flag)
add_env_var "VSCODE_KEYTAR_USE_BASIC_TEXT_ENCRYPTION" "1"

# Reduce GLib/GTK noise in proot
add_env_var "NO_AT_BRIDGE" "1"

# ── Section 10: libsecret / gnome-keyring stubs ───────────────────────────────
# Even with --password-store=basic, VSCode's native module loader still tries
# to dlopen libsecret-1.so.0 at startup. If the library is absent the error is
# printed to the terminal (not fatal, but alarming). Install it so the dlopen
# succeeds and the basic-store path is taken silently.
if [[ "$NO_VSCODE" -eq 0 && "$NO_APT" -eq 0 ]]; then
  msg "Section 10 — Ensuring libsecret-1-0 is present (suppresses dlopen error)"
  set +e
  DEBIAN_FRONTEND=noninteractive apt-get install -y libsecret-1-0 gnome-keyring >/dev/null 2>&1
  set -e
  ok "libsecret-1-0 and gnome-keyring present (or already installed)."
fi

# ── Section 11: ELECTRON_DISABLE_SANDBOX in ~/.bashrc ────────────────────────
msg "Section 11 — Adding ELECTRON_DISABLE_SANDBOX=1 to ~/.bashrc"
if ! grep -qF 'ELECTRON_DISABLE_SANDBOX' ~/.bashrc; then
  echo 'export ELECTRON_DISABLE_SANDBOX=1' >> ~/.bashrc
  ok "ELECTRON_DISABLE_SANDBOX=1 added to ~/.bashrc"
else
  ok "ELECTRON_DISABLE_SANDBOX already present in ~/.bashrc — skipping."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
cat <<'EOT'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[*] All done.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Quick tests
───────────
  Chromium:
    /usr/bin/chromium https://example.com
    exo-open --launch WebBrowser https://example.com

  VSCode:
    code .
    code /path/to/project

  VSCode from XFCE launcher / app menu should also work if --patch-desktop
  was used (or you re-ran with --patch-desktop).

Expected (harmless) proot noise
────────────────────────────────
  These are normal in proot and cannot be silenced:
    - "Failed to move to new namespace: PID namespaces supported, …"
    - dbus / netlink / udev / inotify warnings
    - "SUID sandbox helper binary not found"
    - "Received signal 11" (rare, retry launch)

If VSCode shows the gnome-keyring unlock dialog
────────────────────────────────────────────────
  Cancel it – VSCode will fall back to the basic store automatically.
  The argv.json written by this script already sets password-store=basic
  so the dialog should not appear on subsequent launches.

If VSCode crashes immediately
──────────────────────────────
  Run:  code --verbose --no-sandbox --password-store=basic
  and check for missing shared libraries (ldd /usr/share/code/code).
  Common fix:  apt-get install -y libnss3 libxss1 libatk-bridge2.0-0 \
                   libgtk-3-0 libgbm1 libasound2

EOT
