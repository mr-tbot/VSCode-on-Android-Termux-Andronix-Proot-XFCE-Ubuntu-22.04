#!/bin/bash

# Uninstall Script for VSCode on Android/Termux/Proot
# This script removes VSCode and helper files installed by setup-vscode.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  VSCode Uninstaller for Proot                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    print_info "Please run: sudo bash $0"
    exit 1
fi

print_warning "This will remove:"
echo "  - VSCode application"
echo "  - VSCode launcher (/usr/local/bin/vscode-launcher)"
echo "  - Chrome sandbox script (/usr/local/bin/chrome-no-sandbox.sh)"
echo "  - Helper scripts (/opt/vscode-helpers/)"
echo "  - VSCode repository configuration"
echo ""
print_warning "Your VSCode settings and extensions will be preserved"
echo "  (located in ~/.config/Code/ and ~/.vscode/)"
echo ""

read -p "Are you sure you want to uninstall? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Uninstall cancelled"
    exit 0
fi

echo ""
print_info "Starting uninstall process..."
echo ""

# Remove VSCode
if command -v code &> /dev/null; then
    print_info "Removing VSCode..."
    apt-get remove -y code || print_warning "Failed to remove VSCode package"
    apt-get autoremove -y || true
else
    print_info "VSCode is not installed"
fi

# Remove repository configuration
if [ -f "/etc/apt/sources.list.d/vscode.list" ]; then
    print_info "Removing VSCode repository configuration..."
    rm -f /etc/apt/sources.list.d/vscode.list
fi

if [ -f "/etc/apt/keyrings/packages.microsoft.gpg" ]; then
    rm -f /etc/apt/keyrings/packages.microsoft.gpg
fi

# Remove launcher script
if [ -f "/usr/local/bin/vscode-launcher" ]; then
    print_info "Removing VSCode launcher..."
    rm -f /usr/local/bin/vscode-launcher
fi

# Remove Chrome sandbox script
if [ -f "/usr/local/bin/chrome-no-sandbox.sh" ]; then
    print_info "Removing Chrome sandbox script..."
    rm -f /usr/local/bin/chrome-no-sandbox.sh
fi

# Remove profile entry
if [ -f "/etc/profile" ]; then
    if grep -q "chrome-no-sandbox.sh" /etc/profile; then
        print_info "Removing Chrome sandbox from profile..."
        sed -i '/chrome-no-sandbox.sh/d' /etc/profile
    fi
fi

# Remove helper scripts
if [ -d "/opt/vscode-helpers" ]; then
    print_info "Removing helper scripts..."
    rm -rf /opt/vscode-helpers
fi

# Update package lists
print_info "Updating package lists..."
apt-get update || print_warning "Failed to update package lists"

echo ""
print_info "=========================================="
print_info "Uninstall completed successfully!"
print_info "=========================================="
echo ""
print_info "Your personal VSCode settings are still located at:"
print_info "  ~/.config/Code/"
print_info "  ~/.vscode/"
echo ""
print_info "To completely remove all VSCode data, run:"
print_info "  rm -rf ~/.config/Code ~/.vscode"
echo ""
