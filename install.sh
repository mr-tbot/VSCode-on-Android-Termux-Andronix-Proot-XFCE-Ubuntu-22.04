#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  install.sh — Interactive Proot Development Environment Setup            ║
# ║  Ubuntu 22.04 on Andronix/Termux (arm64)                                ║
# ║                                                                          ║
# ║  Run inside your VNC session (not raw Termux):                           ║
# ║    sudo bash install.sh                                                  ║
# ║                                                                          ║
# ║  Every step is optional. Safe to re-run.                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

# ── Colors & Formatting ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ── Logging helpers ───────────────────────────────────────────────────────────
msg()     { printf "\n${CYAN}[*]${NC} %s\n" "$*"; }
ok()      { printf "  ${GREEN}  ✔${NC} %s\n" "$*"; }
warn()    { printf "  ${YELLOW}  ⚠${NC} %s\n" "$*" >&2; }
err()     { printf "  ${RED}  ✖${NC} %s\n" "$*" >&2; }
info()    { printf "  ${BLUE}  ℹ${NC} %s\n" "$*"; }
header()  {
  printf "\n${BOLD}${MAGENTA}"
  printf '═%.0s' {1..60}
  printf "\n  %s\n" "$*"
  printf '═%.0s' {1..60}
  printf "${NC}\n\n"
}
divider() { printf "${DIM}"; printf '─%.0s' {1..60}; printf "${NC}\n"; }

# ── Root check ────────────────────────────────────────────────────────────────
need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    err "This script must be run as root inside the proot environment."
    echo "Try:  sudo bash $0"
    exit 1
  fi
}

# ── Detect architecture ──────────────────────────────────────────────────────
detect_arch() {
  ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "$ARCH" in
    amd64|x86_64)   DEB_ARCH="amd64"; FLUTTER_ARCH="x64"; GO_ARCH="amd64" ;;
    arm64|aarch64)   DEB_ARCH="arm64"; FLUTTER_ARCH="arm64"; GO_ARCH="arm64" ;;
    armhf|armv7*)    DEB_ARCH="armhf"; FLUTTER_ARCH="arm"; GO_ARCH="armv6l" ;;
    *)               DEB_ARCH="arm64"; FLUTTER_ARCH="arm64"; GO_ARCH="arm64"
                     warn "Unknown architecture '$ARCH' — defaulting to arm64" ;;
  esac
  ok "Architecture detected: $ARCH (deb: $DEB_ARCH)"
}

# ── Prompt helpers ────────────────────────────────────────────────────────────
prompt_yn() {
  # Usage: prompt_yn "Question?" [Y/n]
  local question="$1"
  local default="${2:-y}"
  local yn_hint
  if [[ "${default,,}" == "y" ]]; then yn_hint="[Y/n]"; else yn_hint="[y/N]"; fi
  printf "  ${BOLD}%s${NC} %s " "$question" "$yn_hint"
  read -r answer
  answer="${answer:-$default}"
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

prompt_choice() {
  # Usage: prompt_choice "Question?" "opt1" "opt2" "opt3"
  local question="$1"; shift
  local options=("$@")
  printf "\n  ${BOLD}%s${NC}\n" "$question"
  for i in "${!options[@]}"; do
    printf "    ${CYAN}%d)${NC} %s\n" "$((i+1))" "${options[$i]}"
  done
  printf "  Choice: "
  read -r choice
  echo "$choice"
}

pause_continue() {
  printf "\n  ${DIM}Press Enter to continue...${NC}"
  read -r
}

# ── Track what we installed ───────────────────────────────────────────────────
declare -A INSTALLED_COMPONENTS

mark_installed() { INSTALLED_COMPONENTS["$1"]="yes"; }
is_installed()   { [[ "${INSTALLED_COMPONENTS[$1]:-}" == "yes" ]]; }

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1: Fix sources.list
# ══════════════════════════════════════════════════════════════════════════════
step_fix_sources() {
  header "Step 1: Fix apt sources.list"

  SOURCES=/etc/apt/sources.list
  if [[ ! -f "$SOURCES" ]]; then
    warn "$SOURCES not found — skipping."
    return 0
  fi

  # Show current state
  info "Current sources.list:"
  cat "$SOURCES" | head -30
  divider

  # Backup
  if [[ ! -f "${SOURCES}.bak.prootfix" ]]; then
    cp "$SOURCES" "${SOURCES}.bak.prootfix"
    ok "Backup created: ${SOURCES}.bak.prootfix"
  else
    ok "Backup already exists."
  fi

  # Fix ftp mirrors
  if grep -qE 'ftp[^[:space:]]*\.ubuntu\.com' "$SOURCES"; then
    sed -i -E 's|ftp[^[:space:]]*\.ubuntu\.com|archive.ubuntu.com|g' "$SOURCES"
    ok "Replaced ftp mirror URL(s) with archive.ubuntu.com"
  else
    ok "No ftp mirror URLs found — nothing to replace."
  fi

  # Remove duplicates
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
    ok "Removed $REMOVED duplicate line(s)"
  else
    ok "No duplicates found."
  fi

  # Also check sources.list.d for problematic files
  if [[ -d /etc/apt/sources.list.d ]]; then
    for f in /etc/apt/sources.list.d/*.list; do
      [[ -f "$f" ]] || continue
      # Check for broken GPG key references
      if grep -q 'signed-by=' "$f"; then
        keyfile=$(grep -oP 'signed-by=\K[^\]]+' "$f" | head -1)
        if [[ -n "$keyfile" && ! -f "$keyfile" ]]; then
          warn "Missing GPG key referenced in $f: $keyfile"
          info "This will cause apt errors. The key will be set up if the associated step is run."
        fi
      fi
    done
  fi

  # Validate with apt-get update
  if prompt_yn "Run apt-get update to validate?" "y"; then
    msg "Running apt-get update..."
    local update_output
    update_output=$(apt-get update 2>&1) || true
    local error_count
    error_count=$(echo "$update_output" | grep -ciE '^(Err|E:|W:)' || true)

    if [[ "$error_count" -gt 0 ]]; then
      warn "apt-get update had $error_count warning(s)/error(s):"
      echo "$update_output" | grep -iE '^(Err|E:|W:)' | head -10
      divider
      info "Some warnings are normal in proot. Critical errors may need manual fixing."
    else
      ok "apt-get update completed cleanly!"
    fi
  fi

  mark_installed "sources"
  ok "sources.list fixes complete."
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2: Install & Configure VSCode
# ══════════════════════════════════════════════════════════════════════════════
step_install_vscode() {
  header "Step 2: Install & Configure VSCode"

  local skip_install=0

  # Check if already installed
  if command -v code >/dev/null 2>&1; then
    local ver
    ver=$(code --version 2>/dev/null | head -1 || echo "unknown")
    ok "VSCode is already installed (version: $ver)"
    if ! prompt_yn "Re-apply proot wrappers and config anyway?" "y"; then
      skip_install=1
    fi
  fi

  if [[ "$skip_install" -eq 0 ]]; then
    # Install VSCode if not present
    if ! command -v code >/dev/null 2>&1; then
      msg "Installing VSCode from Microsoft apt repository..."

      # Add Microsoft GPG key
      if [[ ! -f /usr/share/keyrings/microsoft-archive-keyring.gpg ]]; then
        msg "Adding Microsoft GPG key..."
        apt-get install -y wget gpg >/dev/null 2>&1 || true
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
          | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg 2>/dev/null
        ok "GPG key added."
      fi

      # Add repo
      local VSCODE_LIST=/etc/apt/sources.list.d/vscode.list
      if [[ ! -f "$VSCODE_LIST" ]]; then
        echo "deb [arch=${DEB_ARCH} signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > "$VSCODE_LIST"
        ok "VSCode apt repository added."
      fi

      # Install
      apt-get update -qq 2>/dev/null
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apt-transport-https ca-certificates curl gnupg \
        libsecret-1-0 libgbm1 libasound2 code 2>&1 | tail -5
      ok "VSCode installed."
    fi

    # Create proot wrapper
    msg "Setting up proot wrapper for VSCode..."
    local CODE_BIN="/usr/bin/code"

    if [[ -e "$CODE_BIN" ]]; then
      local already_wrapped=0
      if head -n 6 "$CODE_BIN" 2>/dev/null | grep -q "code\.real\|proot VSCode wrapper"; then
        already_wrapped=1
      fi

      if [[ "$already_wrapped" -eq 1 ]]; then
        ok "VSCode wrapper already in place."
      else
        local CODE_REAL_TARGET
        if [[ -L "$CODE_BIN" ]]; then
          CODE_REAL_TARGET="$(readlink -f "$CODE_BIN")"
          rm -f "$CODE_BIN"
        else
          if [[ ! -f /usr/bin/code.real ]]; then
            cp "$CODE_BIN" /usr/bin/code.real
          fi
          CODE_REAL_TARGET="/usr/bin/code.real"
          rm -f "$CODE_BIN"
        fi

        cat > /usr/bin/code <<WRAPPER
#!/bin/sh
# proot VSCode wrapper — installed by install.sh
exec "${CODE_REAL_TARGET}" \\
  --no-sandbox \\
  --disable-gpu \\
  --disable-dev-shm-usage \\
  --disable-software-rasterizer \\
  --password-store=basic \\
  "\$@"
WRAPPER
        chmod +x /usr/bin/code
        ok "VSCode proot wrapper installed."
      fi
    fi

    # argv.json — password-store=basic
    msg "Configuring VSCode keyring settings..."
    _write_vscode_argv() {
      local cfg_dir="$1/Code"
      mkdir -p "$cfg_dir"
      local argv="$cfg_dir/argv.json"
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$argv" <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except Exception:
    data = {}
data["password-store"] = "basic"
data.setdefault("enable-crash-reporter", False)
p.write_text(json.dumps(data, indent=4) + "\n")
PYEOF
        ok "Configured: $argv"
      else
        if [[ ! -f "$argv" ]] || ! grep -q '"password-store"' "$argv" 2>/dev/null; then
          printf '{\n    "password-store": "basic",\n    "enable-crash-reporter": false\n}\n' > "$argv"
          ok "Created: $argv"
        else
          ok "Already configured: $argv"
        fi
      fi
    }

    _write_vscode_argv "/root/.config"
    for home_dir in /home/*/; do
      [[ -d "$home_dir" ]] || continue
      _write_vscode_argv "$home_dir/.config"
    done

    # VSCode settings.json — diffEditor.maxComputationTime=0
    msg "Configuring VSCode settings (diffEditor.maxComputationTime=0)..."
    _write_vscode_settings() {
      local cfg_dir="$1/Code/User"
      mkdir -p "$cfg_dir"
      local settings="$cfg_dir/settings.json"
      if command -v python3 >/dev/null 2>&1; then
        python3 - "$settings" <<'PYEOF'
import sys, json, pathlib
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except Exception:
    data = {}
data["diffEditor.maxComputationTime"] = 0
p.write_text(json.dumps(data, indent=4) + "\n")
PYEOF
        ok "Configured: $settings"
      else
        if [[ ! -f "$settings" ]]; then
          printf '{\n    "diffEditor.maxComputationTime": 0\n}\n' > "$settings"
          ok "Created: $settings"
        elif ! grep -q 'diffEditor.maxComputationTime' "$settings" 2>/dev/null; then
          # Simple append before closing brace
          sed -i 's/}$/,\n    "diffEditor.maxComputationTime": 0\n}/' "$settings" 2>/dev/null || true
          ok "Updated: $settings"
        else
          ok "Already configured: $settings"
        fi
      fi
    }

    _write_vscode_settings "/root/.config"
    for home_dir in /home/*/; do
      [[ -d "$home_dir" ]] || continue
      _write_vscode_settings "$home_dir/.config"
    done

    # Patch .desktop file
    local CODE_DESKTOP=/usr/share/applications/code.desktop
    if [[ -f "$CODE_DESKTOP" ]]; then
      if prompt_yn "Patch code.desktop Exec= lines for proot?" "y"; then
        [[ ! -f "${CODE_DESKTOP}.bak.prootfix" ]] && cp "$CODE_DESKTOP" "${CODE_DESKTOP}.bak.prootfix"
        sed -i 's|^Exec=/usr/share/code/code\b|Exec=/usr/bin/code|g' "$CODE_DESKTOP" || true
        sed -i 's|^Exec=code\b|Exec=/usr/bin/code|g' "$CODE_DESKTOP" || true
        ok "code.desktop patched."
      fi
    fi

    # Install keyring stubs
    msg "Installing libsecret/gnome-keyring stubs..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y libsecret-1-0 gnome-keyring >/dev/null 2>&1 || true
    ok "Keyring libraries present."
  fi

  mark_installed "vscode"
  ok "VSCode setup complete."
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3: Install Browser
# ══════════════════════════════════════════════════════════════════════════════
step_install_browser() {
  header "Step 3: Install Browser"

  info "Available browsers for arm64 proot:"
  echo ""
  printf "    ${CYAN}1)${NC} Chromium          — Recommended, lightweight, well-tested in proot\n"
  printf "    ${CYAN}2)${NC} Firefox            — Full-featured, good compatibility\n"
  printf "    ${CYAN}3)${NC} Firefox ESR        — Extended Support Release, more stable\n"
  printf "    ${DIM}4) Google Chrome     — NOT available for arm64 Linux (x64 only)${NC}\n"
  printf "    ${YELLOW}5) No browser        — ⚠ Some workflows (NDI setup) require a browser${NC}\n"
  echo ""

  printf "  Choose browser [1-5]: "
  read -r browser_choice

  case "$browser_choice" in
    1) _install_chromium ;;
    2) _install_firefox "firefox" ;;
    3) _install_firefox_esr ;;
    4)
      warn "Google Chrome is NOT available as an arm64 .deb package."
      info "Google only builds Chrome for x64 Linux. Chromium is the open-source base"
      info "of Chrome and works identically for development purposes."
      if prompt_yn "Install Chromium instead?" "y"; then
        _install_chromium
      fi
      ;;
    5)
      warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      warn "  No browser will be installed."
      warn "  ⚠ The following workflows will NOT work:"
      warn "    • NDI SDK download (requires browser login)"
      warn "    • OAuth-based Git authentication in VSCode"
      warn "    • Opening documentation/help links from VSCode"
      warn "    • Any web-based registration or download"
      warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      if prompt_yn "Are you sure you want to skip browser installation?" "n"; then
        info "Skipping browser installation."
        return 0
      else
        step_install_browser  # Recurse to re-show menu
        return 0
      fi
      ;;
    *)
      warn "Invalid choice. Skipping browser installation."
      return 0
      ;;
  esac

  mark_installed "browser"
}

_install_chromium() {
  msg "Installing Chromium..."

  if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
    ok "Chromium is already installed."
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser 2>/dev/null || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y chromium 2>/dev/null || {
      err "Failed to install Chromium via apt."
      return 1
    }
    ok "Chromium installed."
  fi

  # Find the actual binary
  local CHROMIUM_BIN=""
  if [[ -e /usr/bin/chromium-browser ]]; then
    CHROMIUM_BIN="/usr/bin/chromium-browser"
  elif [[ -e /usr/bin/chromium ]]; then
    CHROMIUM_BIN="/usr/bin/chromium"
  fi

  if [[ -n "$CHROMIUM_BIN" ]]; then
    # Create proot wrapper
    if head -n 5 "$CHROMIUM_BIN" 2>/dev/null | grep -q "chromium.*\.real\|proot.*wrapper"; then
      ok "Chromium wrapper already in place."
    else
      local CHROMIUM_REAL="${CHROMIUM_BIN}.real"
      if [[ ! -f "$CHROMIUM_REAL" ]]; then
        if [[ -L "$CHROMIUM_BIN" ]]; then
          CHROMIUM_REAL="$(readlink -f "$CHROMIUM_BIN")"
          # Don't move the real binary if it's a different path
          if [[ "$CHROMIUM_REAL" == "$CHROMIUM_BIN" ]]; then
            cp "$CHROMIUM_BIN" "${CHROMIUM_BIN}.real"
            CHROMIUM_REAL="${CHROMIUM_BIN}.real"
          fi
        else
          cp "$CHROMIUM_BIN" "$CHROMIUM_REAL"
        fi
      fi

      cat > "$CHROMIUM_BIN" <<WRAPPER
#!/bin/sh
# proot Chromium wrapper — installed by install.sh
exec "$CHROMIUM_REAL" \\
  --no-sandbox \\
  --disable-dev-shm-usage \\
  --disable-gpu \\
  --disable-software-rasterizer \\
  --no-zygote \\
  "\$@"
WRAPPER
      chmod +x "$CHROMIUM_BIN"
      ok "Chromium proot wrapper installed."
    fi

    # Patch .desktop file
    for desktop_file in /usr/share/applications/chromium*.desktop; do
      [[ -f "$desktop_file" ]] || continue
      if prompt_yn "Patch $(basename "$desktop_file") Exec= lines?" "y"; then
        [[ ! -f "${desktop_file}.bak.prootfix" ]] && cp "$desktop_file" "${desktop_file}.bak.prootfix"
        sed -i "s|^Exec=.*|Exec=$CHROMIUM_BIN %U|" "$desktop_file" || true
        ok "$(basename "$desktop_file") patched."
      fi
    done

    # Set XDG defaults
    if prompt_yn "Set Chromium as default browser?" "y"; then
      _set_xdg_browser "chromium-browser.desktop" "chromium.desktop"
    fi
  fi
}

_install_firefox() {
  local pkg="${1:-firefox}"
  msg "Installing Firefox..."

  if command -v firefox >/dev/null 2>&1; then
    ok "Firefox is already installed."
  else
    # In proot, snap doesn't work. Use apt directly.
    # Ubuntu 22.04 ships a snap-based Firefox by default, so we may need the PPA
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" 2>/dev/null || {
      info "apt install failed — trying Mozilla PPA..."
      apt-get install -y software-properties-common 2>/dev/null || true
      add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null || true
      # Pin PPA over snap
      cat > /etc/apt/preferences.d/mozilla-firefox <<'PIN'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
PIN
      apt-get update -qq 2>/dev/null
      DEBIAN_FRONTEND=noninteractive apt-get install -y firefox 2>/dev/null || {
        err "Failed to install Firefox."
        return 1
      }
    }
    ok "Firefox installed."
  fi

  # Firefox doesn't need --no-sandbox but benefits from some flags in proot
  local FF_BIN="/usr/bin/firefox"
  if [[ -e "$FF_BIN" ]] && ! head -n 5 "$FF_BIN" 2>/dev/null | grep -q "proot.*wrapper"; then
    if prompt_yn "Create proot wrapper for Firefox? (adds MOZ_DISABLE_CONTENT_SANDBOX)" "y"; then
      if [[ ! -f "${FF_BIN}.real" ]]; then
        if [[ -L "$FF_BIN" ]]; then
          local real_target
          real_target="$(readlink -f "$FF_BIN")"
          rm -f "$FF_BIN"
          cat > "$FF_BIN" <<WRAPPER
#!/bin/sh
# proot Firefox wrapper — installed by install.sh
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_GMP_SANDBOX=1
export MOZ_DISABLE_NPAPI_SANDBOX=1
exec "$real_target" "\$@"
WRAPPER
        else
          cp "$FF_BIN" "${FF_BIN}.real"
          cat > "$FF_BIN" <<WRAPPER
#!/bin/sh
# proot Firefox wrapper — installed by install.sh
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_GMP_SANDBOX=1
export MOZ_DISABLE_NPAPI_SANDBOX=1
exec "${FF_BIN}.real" "\$@"
WRAPPER
        fi
        chmod +x "$FF_BIN"
        ok "Firefox proot wrapper installed."
      fi
    fi
  fi

  if prompt_yn "Set Firefox as default browser?" "y"; then
    _set_xdg_browser "firefox.desktop"
  fi
}

_install_firefox_esr() {
  msg "Installing Firefox ESR..."

  if command -v firefox-esr >/dev/null 2>&1; then
    ok "Firefox ESR is already installed."
  else
    # Add Mozilla PPA for ESR
    apt-get install -y software-properties-common 2>/dev/null || true
    add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null || true
    apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y firefox-esr 2>/dev/null || {
      err "Failed to install Firefox ESR."
      return 1
    }
    ok "Firefox ESR installed."
  fi

  # Wrapper
  local FF_BIN="/usr/bin/firefox-esr"
  if [[ -e "$FF_BIN" ]] && ! head -n 5 "$FF_BIN" 2>/dev/null | grep -q "proot.*wrapper"; then
    if prompt_yn "Create proot wrapper for Firefox ESR?" "y"; then
      if [[ ! -f "${FF_BIN}.real" ]]; then
        cp "$FF_BIN" "${FF_BIN}.real"
        cat > "$FF_BIN" <<WRAPPER
#!/bin/sh
# proot Firefox ESR wrapper — installed by install.sh
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_GMP_SANDBOX=1
export MOZ_DISABLE_NPAPI_SANDBOX=1
exec "${FF_BIN}.real" "\$@"
WRAPPER
        chmod +x "$FF_BIN"
        ok "Firefox ESR proot wrapper installed."
      fi
    fi
  fi

  if prompt_yn "Set Firefox ESR as default browser?" "y"; then
    _set_xdg_browser "firefox-esr.desktop"
  fi
}

_set_xdg_browser() {
  # Try each .desktop name provided
  for desktop_name in "$@"; do
    if [[ -f "/usr/share/applications/$desktop_name" ]]; then
      command -v xdg-settings >/dev/null 2>&1 && \
        xdg-settings set default-web-browser "$desktop_name" 2>/dev/null || true
      if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default "$desktop_name" x-scheme-handler/http 2>/dev/null || true
        xdg-mime default "$desktop_name" x-scheme-handler/https 2>/dev/null || true
        xdg-mime default "$desktop_name" text/html 2>/dev/null || true
      fi
      ok "XDG defaults set to $desktop_name"
      return 0
    fi
  done
  warn "Could not find .desktop file to set XDG defaults."
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4: Install Development SDKs
# ══════════════════════════════════════════════════════════════════════════════
step_install_sdks() {
  header "Step 4: Development SDKs"

  while true; do
    echo ""
    printf "    ${CYAN}a)${NC} Node.js (via nvm — LTS)              %s\n" "$(_sdk_status node)"
    printf "    ${CYAN}b)${NC} Python 3 + pip + venv                %s\n" "$(_sdk_status python3)"
    printf "    ${CYAN}c)${NC} Java JDK 17 (OpenJDK)                %s\n" "$(_sdk_status java)"
    printf "    ${CYAN}d)${NC} Android SDK Command-Line Tools        %s\n" "$(_sdk_status sdkmanager)"
    printf "    ${CYAN}e)${NC} Gradle                               %s\n" "$(_sdk_status gradle)"
    printf "    ${CYAN}f)${NC} Flutter SDK                           %s\n" "$(_sdk_status flutter)"
    printf "    ${CYAN}g)${NC} Rust (via rustup)                     %s\n" "$(_sdk_status rustc)"
    printf "    ${CYAN}h)${NC} Go                                    %s\n" "$(_sdk_status go)"
    printf "    ${CYAN}i)${NC} .NET SDK 8.0                          %s\n" "$(_sdk_status dotnet)"
    printf "    ${CYAN}j)${NC} Git + Git LFS + GitHub CLI            %s\n" "$(_sdk_status git)"
    printf "    ${CYAN}k)${NC} Build essentials (gcc, make, cmake)   %s\n" "$(_sdk_status gcc)"
    printf "    ${CYAN}l)${NC} Install ALL SDKs\n"
    printf "    ${CYAN}m)${NC} Back to main menu\n"
    echo ""
    printf "  Choose SDKs (comma-separated, e.g. a,b,c): "
    read -r sdk_choices

    [[ "$sdk_choices" == "m" || "$sdk_choices" == "M" ]] && return 0

    # Normalize
    sdk_choices="${sdk_choices,,}"  # lowercase
    sdk_choices="${sdk_choices// /}" # remove spaces

    if [[ "$sdk_choices" == "l" ]]; then
      sdk_choices="a,b,c,d,e,f,g,h,i,j,k"
    fi

    IFS=',' read -ra choices <<< "$sdk_choices"
    for choice in "${choices[@]}"; do
      case "$choice" in
        a) _sdk_nodejs ;;
        b) _sdk_python ;;
        c) _sdk_java ;;
        d) _sdk_android ;;
        e) _sdk_gradle ;;
        f) _sdk_flutter ;;
        g) _sdk_rust ;;
        h) _sdk_go ;;
        i) _sdk_dotnet ;;
        j) _sdk_git ;;
        k) _sdk_build_essentials ;;
        *) warn "Unknown SDK choice: $choice" ;;
      esac
    done

    if ! prompt_yn "Install more SDKs?" "n"; then
      break
    fi
  done

  mark_installed "sdks"
}

_sdk_status() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "${GREEN}[installed]${NC}"
  else
    printf "${DIM}[not installed]${NC}"
  fi
}

_sdk_nodejs() {
  msg "Installing Node.js via nvm..."

  if command -v nvm >/dev/null 2>&1 || [[ -d "$HOME/.nvm" ]]; then
    ok "nvm already installed."
  else
    info "Installing nvm (Node Version Manager)..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    ok "nvm installed."
  fi

  # Source nvm for this session
  export NVM_DIR="${HOME}/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  if command -v node >/dev/null 2>&1; then
    ok "Node.js already installed: $(node --version)"
    if prompt_yn "Install/update to latest LTS?" "n"; then
      nvm install --lts
      nvm use --lts
      nvm alias default lts/*
    fi
  else
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*
    ok "Node.js LTS installed: $(node --version)"
  fi

  # Install useful global packages
  if prompt_yn "Install common global npm packages? (yarn, pnpm, typescript, eslint)" "y"; then
    npm install -g yarn pnpm typescript eslint @angular/cli 2>/dev/null || true
    ok "Global npm packages installed."
  fi
}

_sdk_python() {
  msg "Installing Python 3 + pip + venv..."

  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 python3-pip python3-venv python3-dev \
    python3-setuptools python3-wheel 2>&1 | tail -3

  ok "Python 3 installed: $(python3 --version)"

  if prompt_yn "Install common Python packages? (requests, flask, django, numpy, black, mypy)" "y"; then
    pip3 install --break-system-packages requests flask django numpy black mypy pylint 2>/dev/null || \
    pip3 install requests flask django numpy black mypy pylint 2>/dev/null || true
    ok "Python packages installed."
  fi
}

_sdk_java() {
  msg "Installing OpenJDK 17..."

  if command -v java >/dev/null 2>&1; then
    ok "Java already installed: $(java -version 2>&1 | head -1)"
    if ! prompt_yn "Reinstall/update?" "n"; then
      return 0
    fi
  fi

  DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk openjdk-17-jdk-headless 2>&1 | tail -3

  # Set JAVA_HOME
  local java_home="/usr/lib/jvm/java-17-openjdk-${DEB_ARCH}"
  if [[ -d "$java_home" ]]; then
    _add_env_var "JAVA_HOME" "$java_home"
    _add_bashrc_export "JAVA_HOME" "$java_home"
    ok "JAVA_HOME set to $java_home"
  fi

  ok "Java installed: $(java -version 2>&1 | head -1)"
}

_sdk_android() {
  msg "Installing Android SDK Command-Line Tools..."

  local ANDROID_HOME="/opt/android-sdk"

  if [[ -d "$ANDROID_HOME/cmdline-tools" ]]; then
    ok "Android SDK cmdline-tools already present at $ANDROID_HOME"
    if ! prompt_yn "Reinstall?" "n"; then
      return 0
    fi
  fi

  # Need Java first
  if ! command -v java >/dev/null 2>&1; then
    warn "Java is required for Android SDK. Installing JDK 17 first..."
    _sdk_java
  fi

  # Need unzip
  DEBIAN_FRONTEND=noninteractive apt-get install -y unzip wget 2>/dev/null || true

  mkdir -p "$ANDROID_HOME"

  # Download latest command-line tools
  info "Downloading Android SDK Command-Line Tools..."
  local CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  local TMP_ZIP="/tmp/android-cmdline-tools.zip"

  wget -q --show-progress -O "$TMP_ZIP" "$CMDLINE_URL" || {
    err "Failed to download Android SDK tools."
    info "You can manually download from: https://developer.android.com/studio#command-line-tools-only"
    return 1
  }

  # Extract to correct structure
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -qo "$TMP_ZIP" -d "$ANDROID_HOME/cmdline-tools/"
  # The zip extracts to cmdline-tools/cmdline-tools — rename to 'latest'
  if [[ -d "$ANDROID_HOME/cmdline-tools/cmdline-tools" ]]; then
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  fi
  rm -f "$TMP_ZIP"

  # Set environment
  _add_env_var "ANDROID_HOME" "$ANDROID_HOME"
  _add_env_var "ANDROID_SDK_ROOT" "$ANDROID_HOME"
  _add_bashrc_export "ANDROID_HOME" "$ANDROID_HOME"
  _add_bashrc_export "ANDROID_SDK_ROOT" "$ANDROID_HOME"
  _add_bashrc_path "$ANDROID_HOME/cmdline-tools/latest/bin"
  _add_bashrc_path "$ANDROID_HOME/platform-tools"

  # Export for current session
  export ANDROID_HOME="$ANDROID_HOME"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

  ok "Android SDK Command-Line Tools installed."

  # Accept licenses and install common components
  if prompt_yn "Accept Android SDK licenses and install platform-tools + build-tools?" "y"; then
    yes | sdkmanager --licenses 2>/dev/null || true
    sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" 2>&1 | tail -5 || true
    ok "Android SDK components installed."
  fi
}

_sdk_gradle() {
  msg "Installing Gradle..."

  if command -v gradle >/dev/null 2>&1; then
    ok "Gradle already installed: $(gradle --version 2>/dev/null | head -3 | tail -1)"
    if ! prompt_yn "Reinstall?" "n"; then
      return 0
    fi
  fi

  local GRADLE_VERSION="8.10.2"
  local GRADLE_HOME="/opt/gradle"

  info "Downloading Gradle $GRADLE_VERSION..."
  wget -q --show-progress -O /tmp/gradle.zip \
    "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" || {
    err "Failed to download Gradle."
    return 1
  }

  mkdir -p "$GRADLE_HOME"
  unzip -qo /tmp/gradle.zip -d "$GRADLE_HOME"
  rm -f /tmp/gradle.zip

  # Create symlink
  ln -sf "$GRADLE_HOME/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle

  # Set memory limits for proot
  mkdir -p "$HOME/.gradle"
  if [[ ! -f "$HOME/.gradle/gradle.properties" ]] || ! grep -q 'jvmargs' "$HOME/.gradle/gradle.properties" 2>/dev/null; then
    cat >> "$HOME/.gradle/gradle.properties" <<'PROPS'
# Proot-friendly memory settings
org.gradle.jvmargs=-Xmx512m -XX:MaxMetaspaceSize=256m
org.gradle.daemon=false
org.gradle.parallel=false
PROPS
    ok "Gradle memory settings configured for proot."
  fi

  ok "Gradle installed: $(gradle --version 2>/dev/null | head -3 | tail -1)"
}

_sdk_flutter() {
  msg "Installing Flutter SDK..."

  if command -v flutter >/dev/null 2>&1; then
    ok "Flutter already installed: $(flutter --version 2>/dev/null | head -1)"
    if ! prompt_yn "Reinstall?" "n"; then
      return 0
    fi
  fi

  local FLUTTER_HOME="/opt/flutter"

  # Dependencies
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build \
    pkg-config libgtk-3-dev 2>/dev/null || true

  info "Cloning Flutter stable channel..."
  if [[ -d "$FLUTTER_HOME" ]]; then
    cd "$FLUTTER_HOME" && git pull 2>/dev/null || true
  else
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_HOME" 2>&1 | tail -3
  fi

  _add_bashrc_path "$FLUTTER_HOME/bin"
  export PATH="$FLUTTER_HOME/bin:$PATH"

  # Disable analytics
  flutter config --no-analytics 2>/dev/null || true

  info "Note: 'flutter doctor' will show warnings about Chrome and Android Studio."
  info "This is expected in proot — use CLI tools instead."

  ok "Flutter installed: $(flutter --version 2>/dev/null | head -1)"
}

_sdk_rust() {
  msg "Installing Rust via rustup..."

  if command -v rustc >/dev/null 2>&1; then
    ok "Rust already installed: $(rustc --version)"
    if ! prompt_yn "Update?" "n"; then
      return 0
    fi
    rustup update 2>/dev/null || true
    return 0
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  ok "Rust installed: $(rustc --version)"
}

_sdk_go() {
  msg "Installing Go..."

  if command -v go >/dev/null 2>&1; then
    ok "Go already installed: $(go version)"
    if ! prompt_yn "Reinstall?" "n"; then
      return 0
    fi
  fi

  local GO_VERSION="1.22.5"
  local GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

  info "Downloading Go $GO_VERSION..."
  wget -q --show-progress -O "/tmp/$GO_TAR" "https://go.dev/dl/$GO_TAR" || {
    err "Failed to download Go."
    return 1
  }

  rm -rf /usr/local/go
  tar -C /usr/local -xzf "/tmp/$GO_TAR"
  rm -f "/tmp/$GO_TAR"

  _add_bashrc_path "/usr/local/go/bin"
  _add_bashrc_export "GOPATH" "$HOME/go"
  _add_bashrc_path "$HOME/go/bin"
  export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

  ok "Go installed: $(go version)"
}

_sdk_dotnet() {
  msg "Installing .NET SDK 8.0..."

  if command -v dotnet >/dev/null 2>&1; then
    ok ".NET already installed: $(dotnet --version)"
    if ! prompt_yn "Reinstall?" "n"; then
      return 0
    fi
  fi

  # Microsoft provides an install script
  info "Downloading .NET install script..."
  wget -q -O /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh || {
    err "Failed to download .NET installer."
    return 1
  }
  chmod +x /tmp/dotnet-install.sh

  /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet 2>&1 | tail -5

  ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet
  _add_env_var "DOTNET_ROOT" "/usr/share/dotnet"
  _add_bashrc_export "DOTNET_ROOT" "/usr/share/dotnet"
  _add_bashrc_export "DOTNET_CLI_TELEMETRY_OPTOUT" "1"

  rm -f /tmp/dotnet-install.sh
  ok ".NET SDK installed: $(dotnet --version 2>/dev/null || echo 'check PATH')"
}

_sdk_git() {
  msg "Installing Git + Git LFS + GitHub CLI..."

  # Git
  if ! command -v git >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y git 2>/dev/null
  fi
  ok "Git: $(git --version)"

  # Git LFS
  if ! command -v git-lfs >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y git-lfs 2>/dev/null || true
    git lfs install 2>/dev/null || true
  fi
  ok "Git LFS: $(git-lfs --version 2>/dev/null || echo 'not installed')"

  # GitHub CLI
  if ! command -v gh >/dev/null 2>&1; then
    info "Installing GitHub CLI..."
    # Add GitHub CLI repo
    if [[ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ]]; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
      echo "deb [arch=${DEB_ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list
    fi
    apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y gh 2>/dev/null || true
  fi
  ok "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not installed')"

  # Configure git if not configured
  if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
    if prompt_yn "Configure git user name and email now?" "y"; then
      printf "  Git user name: "
      read -r git_name
      printf "  Git email: "
      read -r git_email
      git config --global user.name "$git_name"
      git config --global user.email "$git_email"
      ok "Git configured: $git_name <$git_email>"
    fi
  else
    ok "Git user: $(git config --global user.name) <$(git config --global user.email)>"
  fi
}

_sdk_build_essentials() {
  msg "Installing build essentials..."

  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential gcc g++ make cmake pkg-config \
    autoconf automake libtool ninja-build \
    libssl-dev zlib1g-dev libffi-dev 2>&1 | tail -5

  ok "Build essentials installed."
  ok "  gcc: $(gcc --version 2>/dev/null | head -1)"
  ok "  make: $(make --version 2>/dev/null | head -1)"
  ok "  cmake: $(cmake --version 2>/dev/null | head -1)"
}

# ── Environment helpers ───────────────────────────────────────────────────────
_add_env_var() {
  local var="$1" val="$2"
  if grep -q "^${var}=" /etc/environment 2>/dev/null; then
    sed -i "s|^${var}=.*|${var}=${val}|" /etc/environment
  else
    echo "${var}=${val}" >> /etc/environment
  fi
}

_add_bashrc_export() {
  local var="$1" val="$2"
  if ! grep -qF "export ${var}=" ~/.bashrc 2>/dev/null; then
    echo "export ${var}=\"${val}\"" >> ~/.bashrc
  fi
}

_add_bashrc_path() {
  local dir="$1"
  if ! grep -qF "$dir" ~/.bashrc 2>/dev/null; then
    echo "export PATH=\"${dir}:\$PATH\"" >> ~/.bashrc
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5: NDI SDK Setup
# ══════════════════════════════════════════════════════════════════════════════
step_ndi_setup() {
  header "Step 5: NDI SDK Setup"

  info "The NDI (Network Device Interface) SDK requires free registration"
  info "on the NDI website before downloading."
  echo ""
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  warn "  A WORKING BROWSER is required for this step."
  warn "  If you haven't installed a browser yet, do that first (Step 3)."
  warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check if browser is available
  local has_browser=0
  command -v chromium >/dev/null 2>&1 && has_browser=1
  command -v chromium-browser >/dev/null 2>&1 && has_browser=1
  command -v firefox >/dev/null 2>&1 && has_browser=1
  command -v firefox-esr >/dev/null 2>&1 && has_browser=1

  if [[ "$has_browser" -eq 0 ]]; then
    err "No browser detected! Please install a browser first (Main Menu → Step 3)."
    return 1
  fi

  local NDI_DIR="/opt/ndi-sdk"
  if [[ -d "$NDI_DIR" ]] && [[ -f "$NDI_DIR/include/Processing.NDI.Lib.h" ]]; then
    ok "NDI SDK appears to already be installed at $NDI_DIR"
    if ! prompt_yn "Re-install?" "n"; then
      return 0
    fi
  fi

  echo ""
  info "NDI SDK Setup — Two Options:"
  echo ""
  printf "    ${CYAN}1)${NC} Open NDI download page in browser (you register & download)\n"
  printf "    ${CYAN}2)${NC} Paste a direct download URL (if you already received one via email)\n"
  printf "    ${CYAN}3)${NC} Show manual instructions only\n"
  echo ""
  printf "  Choose [1-3]: "
  read -r ndi_choice

  case "$ndi_choice" in
    1)
      msg "Opening NDI download page..."
      info "Steps:"
      info "  1. Register for a free NDI developer account (if you haven't)"
      info "  2. Download the 'NDI SDK for Linux' (arm64 version)"
      info "  3. The file will download to your browser's download folder"
      info "     (usually ~/Downloads/)"
      info "  4. Come back here when the download is complete"
      echo ""

      # Open the NDI download page
      local browser_cmd=""
      command -v chromium >/dev/null 2>&1 && browser_cmd="chromium"
      command -v chromium-browser >/dev/null 2>&1 && browser_cmd="chromium-browser"
      command -v firefox >/dev/null 2>&1 && browser_cmd="firefox"
      command -v firefox-esr >/dev/null 2>&1 && browser_cmd="firefox-esr"

      if [[ -n "$browser_cmd" ]]; then
        "$browser_cmd" "https://ndi.video/for-developers/ndi-sdk/" &
        disown 2>/dev/null || true
      fi

      echo ""
      info "Waiting for you to download the NDI SDK..."
      info "Press Enter when the download is complete, or type 'skip' to skip."
      printf "  > "
      read -r ndi_wait
      [[ "$ndi_wait" == "skip" ]] && return 0

      _ndi_find_and_install
      ;;
    2)
      echo ""
      printf "  Paste the NDI SDK download URL: "
      read -r ndi_url

      if [[ -z "$ndi_url" ]]; then
        warn "No URL provided. Skipping NDI install."
        return 0
      fi

      msg "Downloading NDI SDK..."
      local ndi_file="/tmp/ndi-sdk-download.tar.gz"
      wget -q --show-progress -O "$ndi_file" "$ndi_url" || {
        # Try as .sh installer
        ndi_file="/tmp/ndi-sdk-download.sh"
        wget -q --show-progress -O "$ndi_file" "$ndi_url" || {
          err "Download failed."
          return 1
        }
      }

      _ndi_install_file "$ndi_file"
      ;;
    3)
      _ndi_show_instructions
      ;;
    *)
      warn "Invalid choice."
      ;;
  esac
}

_ndi_find_and_install() {
  msg "Looking for NDI SDK download..."

  local ndi_file=""
  # Check common download locations
  for dir in ~/Downloads /tmp /root/Downloads; do
    if [[ -d "$dir" ]]; then
      local found
      found=$(find "$dir" -maxdepth 1 -name '*NDI*' -o -name '*ndi*' 2>/dev/null | \
              sort -t/ -k2 -r | head -1)
      if [[ -n "$found" ]]; then
        ndi_file="$found"
        break
      fi
    fi
  done

  if [[ -z "$ndi_file" ]]; then
    warn "Could not find NDI SDK file automatically."
    printf "  Enter the full path to the downloaded NDI SDK file: "
    read -r ndi_file
  fi

  if [[ -z "$ndi_file" || ! -f "$ndi_file" ]]; then
    err "File not found: $ndi_file"
    _ndi_show_instructions
    return 1
  fi

  _ndi_install_file "$ndi_file"
}

_ndi_install_file() {
  local file="$1"
  local NDI_DIR="/opt/ndi-sdk"

  msg "Installing NDI SDK from: $file"

  mkdir -p "$NDI_DIR"

  if [[ "$file" == *.tar.gz || "$file" == *.tgz ]]; then
    tar -xzf "$file" -C "$NDI_DIR" --strip-components=1 2>/dev/null || \
    tar -xzf "$file" -C "$NDI_DIR" 2>/dev/null || {
      err "Failed to extract NDI SDK."
      return 1
    }
  elif [[ "$file" == *.sh ]]; then
    chmod +x "$file"
    # NDI's .sh installers usually accept a EULA and extract
    info "Running NDI SDK installer (you may need to accept the EULA)..."
    PAGER=cat "$file" 2>/dev/null || bash "$file" 2>/dev/null || {
      err "Failed to run NDI SDK installer."
      return 1
    }
    # The installer usually creates a folder — find it
    local ndi_extracted
    ndi_extracted=$(find /tmp /opt /root -maxdepth 2 -type d -name '*NDI*SDK*' 2>/dev/null | head -1)
    if [[ -n "$ndi_extracted" && "$ndi_extracted" != "$NDI_DIR" ]]; then
      cp -r "$ndi_extracted"/* "$NDI_DIR/" 2>/dev/null || true
    fi
  elif [[ "$file" == *.zip ]]; then
    unzip -qo "$file" -d "$NDI_DIR" 2>/dev/null || {
      err "Failed to extract NDI SDK."
      return 1
    }
  else
    warn "Unknown file format. Trying to extract as tar.gz..."
    tar -xzf "$file" -C "$NDI_DIR" 2>/dev/null || tar -xf "$file" -C "$NDI_DIR" 2>/dev/null || {
      err "Could not extract file."
      return 1
    }
  fi

  # Set up library paths
  local ndi_lib=""
  ndi_lib=$(find "$NDI_DIR" -name 'libndi.so*' -type f 2>/dev/null | head -1)
  if [[ -n "$ndi_lib" ]]; then
    local ndi_lib_dir
    ndi_lib_dir=$(dirname "$ndi_lib")
    echo "$ndi_lib_dir" > /etc/ld.so.conf.d/ndi.conf
    ldconfig 2>/dev/null || true
    ok "NDI library path registered: $ndi_lib_dir"
  fi

  # Set environment
  _add_env_var "NDI_SDK_DIR" "$NDI_DIR"
  _add_bashrc_export "NDI_SDK_DIR" "$NDI_DIR"

  ok "NDI SDK installed to $NDI_DIR"
  mark_installed "ndi"
}

_ndi_show_instructions() {
  echo ""
  divider
  printf "${BOLD}  NDI SDK Manual Installation Instructions${NC}\n"
  divider
  echo ""
  info "1. Open your browser and go to:"
  echo "     https://ndi.video/for-developers/ndi-sdk/"
  echo ""
  info "2. Click 'Download' and register for a free account if needed."
  echo ""
  info "3. Download the 'NDI SDK for Linux' (choose the arm64/aarch64 version)"
  echo ""
  info "4. Once downloaded, the file will be in ~/Downloads/ (or wherever"
  info "   your browser saves files)."
  echo ""
  info "5. Run this command to install:"
  echo "     sudo mkdir -p /opt/ndi-sdk"
  echo "     sudo tar -xzf ~/Downloads/NDI_SDK_*.tar.gz -C /opt/ndi-sdk --strip-components=1"
  echo ""
  info "   OR if it's a .sh installer:"
  echo "     chmod +x ~/Downloads/Install_NDI_SDK_*.sh"
  echo "     sudo ~/Downloads/Install_NDI_SDK_*.sh"
  echo ""
  info "6. Set up the library path:"
  echo "     echo '/opt/ndi-sdk/lib/aarch64-linux-gnu' | sudo tee /etc/ld.so.conf.d/ndi.conf"
  echo "     sudo ldconfig"
  echo ""
  info "7. Add to your environment:"
  echo "     echo 'export NDI_SDK_DIR=/opt/ndi-sdk' >> ~/.bashrc"
  echo ""
  info "8. Re-run this installer and choose Step 8 to validate the installation."
  divider
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6: Fix Desktop Icons
# ══════════════════════════════════════════════════════════════════════════════
step_fix_icons() {
  header "Step 6: Fix Missing Desktop Icons"

  info "In proot XFCE environments, icons often show as blank/missing"
  info "because icon theme packages are not fully installed."
  echo ""

  if prompt_yn "Are you experiencing missing/blank icons in XFCE?" "y"; then
    echo ""
    printf "    ${CYAN}1)${NC} Install Adwaita icon theme (GNOME default, comprehensive)\n"
    printf "    ${CYAN}2)${NC} Install Papirus icon theme (modern, popular, very complete)\n"
    printf "    ${CYAN}3)${NC} Install both\n"
    echo ""
    printf "  Choose [1-3]: "
    read -r icon_choice

    case "$icon_choice" in
      1)
        msg "Installing Adwaita icon theme..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y adwaita-icon-theme-full 2>&1 | tail -3
        ok "Adwaita icon theme installed."
        ;;
      2)
        _install_papirus_icons
        ;;
      3)
        msg "Installing Adwaita icon theme..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y adwaita-icon-theme-full 2>&1 | tail -3
        ok "Adwaita installed."
        _install_papirus_icons
        ;;
      *)
        warn "Invalid choice."
        return 0
        ;;
    esac

    # Update icon caches
    msg "Updating icon caches..."
    for theme_dir in /usr/share/icons/*/; do
      gtk-update-icon-cache -f -t "$theme_dir" 2>/dev/null || true
    done
    update-icon-caches /usr/share/icons 2>/dev/null || true
    ok "Icon caches updated."

    # Optionally set as active theme
    if [[ "$icon_choice" == "2" || "$icon_choice" == "3" ]]; then
      if prompt_yn "Set Papirus as the active XFCE icon theme?" "y"; then
        xfconf-query -c xsettings -p /Net/IconThemeName -s Papirus 2>/dev/null || true
        ok "Papirus set as active icon theme."
        info "You may need to log out and back in for all icons to update."
      fi
    fi

    # Also install hicolor (base theme that others depend on)
    DEBIAN_FRONTEND=noninteractive apt-get install -y hicolor-icon-theme 2>/dev/null || true

    mark_installed "icons"
    ok "Icon fix complete."
  else
    info "Skipping icon fix."
  fi
}

_install_papirus_icons() {
  msg "Installing Papirus icon theme..."
  # Try apt first
  DEBIAN_FRONTEND=noninteractive apt-get install -y papirus-icon-theme 2>/dev/null || {
    # Fallback: add PPA
    info "Adding Papirus PPA..."
    apt-get install -y software-properties-common 2>/dev/null || true
    add-apt-repository -y ppa:papirus/papirus 2>/dev/null || true
    apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y papirus-icon-theme 2>/dev/null || {
      err "Failed to install Papirus. Try: apt install papirus-icon-theme"
      return 1
    }
  }
  ok "Papirus icon theme installed."
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7: Apply Proot Environment Tweaks
# ══════════════════════════════════════════════════════════════════════════════
step_env_tweaks() {
  header "Step 7: Proot Environment Tweaks"

  info "These settings suppress common Electron/Chromium errors in proot"
  info "and configure the environment for development work."
  echo ""

  if ! prompt_yn "Apply proot environment tweaks?" "y"; then
    return 0
  fi

  # /etc/environment
  msg "Updating /etc/environment..."
  _add_env_var "LIBGL_ALWAYS_SOFTWARE" "1"
  _add_env_var "ELECTRON_DISABLE_GPU" "1"
  _add_env_var "ELECTRON_DISABLE_SECURITY_WARNINGS" "1"
  _add_env_var "VSCODE_KEYTAR_USE_BASIC_TEXT_ENCRYPTION" "1"
  _add_env_var "NO_AT_BRIDGE" "1"
  _add_env_var "ELECTRON_DISABLE_SANDBOX" "1"
  ok "/etc/environment updated."

  # ~/.bashrc
  msg "Updating ~/.bashrc..."
  _add_bashrc_export "ELECTRON_DISABLE_SANDBOX" "1"

  # XDG directories
  if ! grep -qF 'XDG_CONFIG_HOME' ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc <<'BASHRC'

# XDG Base Directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
BASHRC
    ok "XDG base directories added to ~/.bashrc"
  fi

  # at-spi2-core (reduces warning spam)
  if prompt_yn "Install at-spi2-core? (reduces AT-SPI warning spam in terminal)" "y"; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y at-spi2-core 2>/dev/null || true
    ok "at-spi2-core installed."
  fi

  # dbus (sometimes missing in proot)
  if ! command -v dbus-daemon >/dev/null 2>&1; then
    if prompt_yn "Install dbus? (can fix some application launch issues)" "y"; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y dbus dbus-x11 2>/dev/null || true
      ok "dbus installed."
    fi
  fi

  mark_installed "env_tweaks"
  ok "Environment tweaks applied."
  info "Some changes require a new terminal session or login to take effect."
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8: Validate Installation
# ══════════════════════════════════════════════════════════════════════════════
step_validate() {
  header "Step 8: Validate Installation"

  local total=0
  local passed=0
  local failed=0
  local warnings=0

  _check() {
    local name="$1" cmd="$2"
    total=$((total+1))
    if eval "$cmd" >/dev/null 2>&1; then
      passed=$((passed+1))
      local ver
      ver=$(eval "$3" 2>/dev/null || echo "ok")
      printf "  ${GREEN}✔${NC} %-35s %s\n" "$name" "$ver"
    else
      failed=$((failed+1))
      printf "  ${RED}✖${NC} %-35s ${DIM}not found${NC}\n" "$name"
    fi
  }

  _check_warn() {
    local name="$1" cmd="$2"
    total=$((total+1))
    if eval "$cmd" >/dev/null 2>&1; then
      passed=$((passed+1))
      local ver
      ver=$(eval "$3" 2>/dev/null || echo "ok")
      printf "  ${GREEN}✔${NC} %-35s %s\n" "$name" "$ver"
    else
      warnings=$((warnings+1))
      printf "  ${YELLOW}⚠${NC} %-35s ${DIM}not installed (optional)${NC}\n" "$name"
    fi
  }

  echo ""
  printf "  ${BOLD}Core Components${NC}\n"
  divider
  _check "apt sources.list" "test -f /etc/apt/sources.list" "echo 'present'"
  _check "VSCode" "command -v code" "code --version 2>/dev/null | head -1"
  _check "Browser" "command -v chromium || command -v chromium-browser || command -v firefox || command -v firefox-esr" "echo 'installed'"

  echo ""
  printf "  ${BOLD}Development SDKs${NC}\n"
  divider
  _check_warn "Node.js" "command -v node" "node --version"
  _check_warn "npm" "command -v npm" "npm --version"
  _check_warn "Python 3" "command -v python3" "python3 --version"
  _check_warn "pip3" "command -v pip3" "pip3 --version 2>/dev/null | head -1"
  _check_warn "Java" "command -v java" "java -version 2>&1 | head -1"
  _check_warn "Android SDK (sdkmanager)" "command -v sdkmanager" "sdkmanager --version 2>/dev/null | head -1"
  _check_warn "Gradle" "command -v gradle" "gradle --version 2>/dev/null | grep Gradle | head -1"
  _check_warn "Flutter" "command -v flutter" "flutter --version 2>/dev/null | head -1"
  _check_warn "Rust (rustc)" "command -v rustc" "rustc --version"
  _check_warn "Go" "command -v go" "go version"
  _check_warn ".NET" "command -v dotnet" "dotnet --version"
  _check_warn "Git" "command -v git" "git --version"
  _check_warn "GitHub CLI" "command -v gh" "gh --version 2>/dev/null | head -1"
  _check_warn "gcc" "command -v gcc" "gcc --version 2>/dev/null | head -1"
  _check_warn "cmake" "command -v cmake" "cmake --version 2>/dev/null | head -1"

  echo ""
  printf "  ${BOLD}Special SDKs${NC}\n"
  divider
  _check_warn "NDI SDK" "test -d /opt/ndi-sdk" "echo '/opt/ndi-sdk'"

  echo ""
  printf "  ${BOLD}Environment${NC}\n"
  divider
  _check "ELECTRON_DISABLE_SANDBOX" "grep -q ELECTRON_DISABLE_SANDBOX /etc/environment 2>/dev/null" "echo 'set'"
  _check_warn "password-store=basic" "grep -q password-store /root/.config/Code/argv.json 2>/dev/null" "echo 'configured'"
  _check_warn "diffEditor.maxComputationTime=0" "grep -q 'maxComputationTime.*0' /root/.config/Code/User/settings.json 2>/dev/null" "echo 'configured'"

  # apt update check
  echo ""
  printf "  ${BOLD}apt Repository Health${NC}\n"
  divider
  msg "Running apt-get update (quick check)..."
  local apt_out
  apt_out=$(apt-get update 2>&1) || true
  local apt_errors
  apt_errors=$(echo "$apt_out" | grep -ciE '^(Err|E:)' || true)
  local apt_warnings
  apt_warnings=$(echo "$apt_out" | grep -ciE '^W:' || true)

  if [[ "$apt_errors" -eq 0 ]]; then
    printf "  ${GREEN}✔${NC} apt-get update — no errors\n"
  else
    printf "  ${RED}✖${NC} apt-get update — $apt_errors error(s)\n"
    echo "$apt_out" | grep -iE '^(Err|E:)' | head -5
  fi
  if [[ "$apt_warnings" -gt 0 ]]; then
    printf "  ${YELLOW}⚠${NC} apt-get update — $apt_warnings warning(s) (usually harmless in proot)\n"
  fi

  # Summary
  echo ""
  divider
  printf "  ${BOLD}Summary:${NC} %d checked | ${GREEN}%d passed${NC} | ${RED}%d failed${NC} | ${YELLOW}%d optional missing${NC}\n" \
    "$total" "$passed" "$failed" "$warnings"
  divider

  if [[ "$failed" -gt 0 ]]; then
    warn "Some core components are missing. Run the corresponding install step."
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9: Run All
# ══════════════════════════════════════════════════════════════════════════════
step_run_all() {
  header "Run All Steps (Fresh Install)"

  warn "This will run all installation steps interactively."
  warn "Each step will still ask for confirmations."
  echo ""

  if ! prompt_yn "Proceed with full installation?" "y"; then
    return 0
  fi

  step_fix_sources
  step_install_vscode
  step_install_browser
  step_install_sdks
  step_ndi_setup
  step_fix_icons
  step_env_tweaks
  step_validate
}

# ══════════════════════════════════════════════════════════════════════════════
# Main Menu
# ══════════════════════════════════════════════════════════════════════════════
main_menu() {
  while true; do
    clear 2>/dev/null || true
    printf "${BOLD}${MAGENTA}"
    cat <<'BANNER'
  ╔═══════════════════════════════════════════════════════════╗
  ║   Proot Development Environment Setup                    ║
  ║   Ubuntu 22.04 · Andronix/Termux · arm64                ║
  ╚═══════════════════════════════════════════════════════════╝
BANNER
    printf "${NC}\n"

    printf "    ${CYAN}1)${NC} Fix apt sources.list %s\n" "$(is_installed sources && echo '✔' || echo '')"
    printf "    ${CYAN}2)${NC} Install & configure VSCode %s\n" "$(is_installed vscode && echo '✔' || echo '')"
    printf "    ${CYAN}3)${NC} Install browser (Chromium/Firefox/Firefox ESR) %s\n" "$(is_installed browser && echo '✔' || echo '')"
    printf "    ${CYAN}4)${NC} Install development SDKs %s\n" "$(is_installed sdks && echo '✔' || echo '')"
    printf "    ${CYAN}5)${NC} NDI SDK setup (requires browser) %s\n" "$(is_installed ndi && echo '✔' || echo '')"
    printf "    ${CYAN}6)${NC} Fix missing desktop/taskbar icons %s\n" "$(is_installed icons && echo '✔' || echo '')"
    printf "    ${CYAN}7)${NC} Apply proot environment tweaks %s\n" "$(is_installed env_tweaks && echo '✔' || echo '')"
    printf "    ${CYAN}8)${NC} Validate installation\n"
    printf "    ${GREEN}9)${NC} ${BOLD}Run ALL steps${NC} (recommended for fresh installs)\n"
    printf "    ${RED}0)${NC} Exit\n"
    echo ""
    printf "  Choose an option [0-9]: "
    read -r choice

    case "$choice" in
      1) step_fix_sources; pause_continue ;;
      2) step_install_vscode; pause_continue ;;
      3) step_install_browser; pause_continue ;;
      4) step_install_sdks; pause_continue ;;
      5) step_ndi_setup; pause_continue ;;
      6) step_fix_icons; pause_continue ;;
      7) step_env_tweaks; pause_continue ;;
      8) step_validate; pause_continue ;;
      9) step_run_all; pause_continue ;;
      0)
        echo ""
        ok "Goodbye! Don't forget to open a new terminal for changes to take effect."
        exit 0
        ;;
      *)
        warn "Invalid option. Please choose 0-9."
        sleep 1
        ;;
    esac
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# Entry Point
# ══════════════════════════════════════════════════════════════════════════════
need_root
detect_arch
main_menu
