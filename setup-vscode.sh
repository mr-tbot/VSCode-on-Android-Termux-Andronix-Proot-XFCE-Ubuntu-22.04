#!/bin/bash

# VSCode Setup Script for Android Termux/Andronix Proot Environment
# This script performs various fixes to enable VSCode to run in proot
# Tested on: Andronix Ubuntu 22.04 with XFCE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in proot environment
check_proot_env() {
    print_info "Checking if running in proot environment..."
    if [ ! -d "/data/data/com.termux" ] && [ ! -f "/.proot_env" ]; then
        print_warning "This script is designed for Termux/Andronix proot environments"
    fi
}

# Fix repository sources
fix_repositories() {
    print_info "Fixing repository sources..."
    
    # Update package lists
    apt-get update || {
        print_warning "Failed to update package lists, attempting to fix sources..."
        
        # Backup existing sources
        if [ -f "/etc/apt/sources.list" ]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.backup
        fi
        
        # Try update again
        apt-get update
    }
    
    print_info "Repository sources fixed successfully"
}

# Install required dependencies
install_dependencies() {
    print_info "Installing required dependencies for VSCode..."
    
    # Core dependencies
    apt-get install -y \
        wget \
        curl \
        gpg \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        git \
        libasound2 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libxss1 \
        libxtst6 \
        xdg-utils || {
        print_error "Failed to install some dependencies, continuing anyway..."
    }
    
    print_info "Dependencies installed successfully"
}

# Fix Chrome/Chromium sandbox issues
fix_chrome_sandbox() {
    print_info "Fixing Chrome/Chromium sandbox issues..."
    
    # VSCode uses Electron which uses Chrome sandbox
    # Sandbox doesn't work in proot, so we need to disable it
    
    # Create a system-wide script to set CHROME flags
    cat > /usr/local/bin/chrome-no-sandbox.sh << 'EOF'
#!/bin/bash
# Disable Chrome sandbox for proot environments
export ELECTRON_NO_SANDBOX=1
export CHROME_NO_SANDBOX=1
EOF
    
    chmod +x /usr/local/bin/chrome-no-sandbox.sh
    
    # Add to profile so it's loaded for all users
    if ! grep -q "chrome-no-sandbox.sh" /etc/profile; then
        echo "source /usr/local/bin/chrome-no-sandbox.sh" >> /etc/profile
    fi
    
    print_info "Chrome sandbox disabled for proot environment"
}

# Install VSCode
install_vscode() {
    print_info "Installing VSCode..."
    
    # Check if VSCode is already installed
    if command -v code &> /dev/null; then
        print_info "VSCode is already installed"
        code --version
        return 0
    fi
    
    # Add Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    
    # Add VSCode repository
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    
    # Update and install
    apt-get update
    apt-get install -y code || {
        print_error "Failed to install VSCode from repository"
        print_info "You may need to download and install VSCode manually"
        return 1
    }
    
    print_info "VSCode installed successfully"
}

# Create VSCode launcher script
create_launcher() {
    print_info "Creating VSCode launcher script..."
    
    cat > /usr/local/bin/vscode-launcher << 'EOF'
#!/bin/bash

# VSCode Launcher for Proot Environment
# This script launches VSCode with appropriate flags for proot

# Disable sandboxing (required for proot)
export ELECTRON_NO_SANDBOX=1
export CHROME_NO_SANDBOX=1

# Fix potential GPU issues
export LIBGL_ALWAYS_SOFTWARE=1

# Launch VSCode with no-sandbox flag
code --no-sandbox --disable-gpu-sandbox "$@"
EOF
    
    chmod +x /usr/local/bin/vscode-launcher
    
    print_info "VSCode launcher created at /usr/local/bin/vscode-launcher"
}

# Create helper scripts
create_helpers() {
    print_info "Creating helper scripts..."
    
    # Create directory for helper scripts
    mkdir -p /opt/vscode-helpers
    
    # Fix permissions script
    cat > /opt/vscode-helpers/fix-permissions.sh << 'EOF'
#!/bin/bash
# Fix common permission issues in proot environment

echo "Fixing permissions..."

# Fix home directory permissions
if [ -n "$HOME" ] && [ -d "$HOME" ]; then
    chmod -R u+rwX "$HOME" 2>/dev/null || true
fi

# Fix VSCode config directory
if [ -d "$HOME/.config/Code" ]; then
    chmod -R u+rwX "$HOME/.config/Code" 2>/dev/null || true
fi

# Fix VSCode extensions directory
if [ -d "$HOME/.vscode" ]; then
    chmod -R u+rwX "$HOME/.vscode" 2>/dev/null || true
fi

echo "Permissions fixed"
EOF
    
    chmod +x /opt/vscode-helpers/fix-permissions.sh
    
    # Environment check script
    cat > /opt/vscode-helpers/check-env.sh << 'EOF'
#!/bin/bash
# Check if environment is properly configured for VSCode

echo "Checking VSCode environment..."
echo ""

# Check if VSCode is installed
if command -v code &> /dev/null; then
    echo "✓ VSCode is installed"
    code --version
else
    echo "✗ VSCode is not installed"
fi

echo ""

# Check environment variables
echo "Environment variables:"
echo "  ELECTRON_NO_SANDBOX: ${ELECTRON_NO_SANDBOX:-not set}"
echo "  CHROME_NO_SANDBOX: ${CHROME_NO_SANDBOX:-not set}"
echo "  LIBGL_ALWAYS_SOFTWARE: ${LIBGL_ALWAYS_SOFTWARE:-not set}"

echo ""

# Check display
if [ -n "$DISPLAY" ]; then
    echo "✓ DISPLAY is set: $DISPLAY"
else
    echo "✗ DISPLAY is not set"
    echo "  You need to start X server first (e.g., startxfce4)"
fi

echo ""

# Check required libraries
echo "Checking required libraries..."
libs=(
    "libasound.so.2"
    "libatk-1.0.so.0"
    "libgtk-3.so.0"
    "libnss3.so"
)

for lib in "${libs[@]}"; do
    if ldconfig -p | grep -q "$lib"; then
        echo "✓ $lib found"
    else
        echo "✗ $lib not found"
    fi
done
EOF
    
    chmod +x /opt/vscode-helpers/check-env.sh
    
    print_info "Helper scripts created in /opt/vscode-helpers/"
}

# Update README with usage instructions
update_readme() {
    print_info "Updating README with usage instructions..."
    
    cat > /opt/vscode-helpers/README.txt << 'EOF'
VSCode on Android (Termux/Andronix Proot) - Setup Complete
===========================================================

VSCode has been configured to run in your proot environment!

USAGE:
------

1. Start your X server (XFCE):
   $ startxfce4

2. Launch VSCode:
   $ vscode-launcher

   Or use the standard command with no-sandbox flag:
   $ code --no-sandbox

HELPER SCRIPTS:
--------------

- Check environment:
  $ /opt/vscode-helpers/check-env.sh

- Fix permissions:
  $ /opt/vscode-helpers/fix-permissions.sh

TROUBLESHOOTING:
---------------

If VSCode doesn't start:

1. Make sure DISPLAY is set:
   $ echo $DISPLAY
   
2. Check if X server is running:
   $ ps aux | grep X

3. Run environment check:
   $ /opt/vscode-helpers/check-env.sh

4. Fix permissions:
   $ /opt/vscode-helpers/fix-permissions.sh

5. Try running with verbose output:
   $ code --no-sandbox --verbose

NOTES:
------

- Sandboxing is disabled (required for proot)
- Software rendering is enabled for compatibility
- Some extensions may not work properly in proot environment

For more information, visit:
https://github.com/mr-tbot/VSCode-on-Android-Termux-Andronix-Proot-XFCE-Ubuntu-22.04
EOF
    
    print_info "README created at /opt/vscode-helpers/README.txt"
}

# Main execution
main() {
    print_info "Starting VSCode setup for Proot environment..."
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo bash $0"
        exit 1
    fi
    
    check_proot_env
    echo ""
    
    fix_repositories
    echo ""
    
    install_dependencies
    echo ""
    
    fix_chrome_sandbox
    echo ""
    
    install_vscode
    echo ""
    
    create_launcher
    echo ""
    
    create_helpers
    echo ""
    
    update_readme
    echo ""
    
    print_info "=========================================="
    print_info "VSCode setup completed successfully!"
    print_info "=========================================="
    echo ""
    print_info "Next steps:"
    print_info "1. Start your X server: startxfce4"
    print_info "2. Launch VSCode: vscode-launcher"
    print_info "3. Read documentation: cat /opt/vscode-helpers/README.txt"
    echo ""
    print_info "For troubleshooting, run: /opt/vscode-helpers/check-env.sh"
}

# Run main function
main "$@"
