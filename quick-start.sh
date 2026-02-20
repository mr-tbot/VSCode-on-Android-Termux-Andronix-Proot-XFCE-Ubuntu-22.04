#!/bin/bash

# Quick Start Script for VSCode on Android/Termux/Proot
# This is a simplified wrapper for the main setup script

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  VSCode on Android - Quick Start                           ║"
echo "║  Termux/Andronix Proot Setup                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges."
    echo "Restarting with sudo..."
    echo ""
    exec sudo bash "$0" "$@"
fi

# Check if setup script exists
if [ ! -f "setup-vscode.sh" ]; then
    echo "Error: setup-vscode.sh not found in current directory"
    echo "Please run this script from the repository root directory"
    exit 1
fi

echo "Starting VSCode setup..."
echo "This will:"
echo "  - Fix repository sources"
echo "  - Install dependencies"
echo "  - Fix Chrome sandbox for proot"
echo "  - Install VSCode"
echo "  - Create helper scripts"
echo ""
echo "This may take several minutes depending on your internet speed."
echo ""

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Run the main setup script
bash setup-vscode.sh

# Check if setup was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Setup Complete!                                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Quick Start:"
    echo "  1. Start XFCE: startxfce4"
    echo "  2. Launch VSCode: vscode-launcher"
    echo ""
    echo "For more information:"
    echo "  cat /opt/vscode-helpers/README.txt"
    echo ""
else
    echo ""
    echo "Setup encountered errors. Please check the output above."
    exit 1
fi
