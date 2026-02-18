#!/bin/bash

# Test script to validate the setup-vscode.sh logic
# This performs dry-run tests without actually installing packages

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  VSCode Setup Script - Validation Tests                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-vscode.sh"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result tracking
test_pass() {
    echo "  ✓ $1"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

test_fail() {
    echo "  ✗ $1"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

# Test 1: Check if setup script exists
echo "[Test 1] Checking if setup-vscode.sh exists..."
if [ -f "$SETUP_SCRIPT" ]; then
    test_pass "setup-vscode.sh found"
else
    test_fail "setup-vscode.sh not found"
fi

# Test 2: Check if setup script is executable
echo "[Test 2] Checking if setup-vscode.sh is executable..."
if [ -x "$SETUP_SCRIPT" ]; then
    test_pass "setup-vscode.sh is executable"
else
    test_fail "setup-vscode.sh is not executable"
fi

# Test 3: Validate bash syntax
echo "[Test 3] Validating bash syntax..."
if bash -n "$SETUP_SCRIPT" 2>/dev/null; then
    test_pass "Bash syntax is valid"
else
    test_fail "Bash syntax is invalid"
fi

# Test 4: Check for required functions
echo "[Test 4] Checking for required functions..."
REQUIRED_FUNCTIONS=(
    "check_proot_env"
    "fix_repositories"
    "install_dependencies"
    "fix_chrome_sandbox"
    "install_vscode"
    "create_launcher"
    "create_helpers"
    "update_readme"
)

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" "$SETUP_SCRIPT"; then
        test_pass "Function '$func' is defined"
    else
        test_fail "Function '$func' is missing"
    fi
done

# Test 5: Check for proper error handling
echo "[Test 5] Checking for error handling..."
if grep -q "set -e" "$SETUP_SCRIPT"; then
    test_pass "Script has 'set -e' for error handling"
else
    test_fail "Script missing 'set -e' for error handling"
fi

# Test 6: Check for environment variable exports
echo "[Test 6] Checking for required environment variables..."
REQUIRED_ENV_VARS=(
    "ELECTRON_NO_SANDBOX"
    "CHROME_NO_SANDBOX"
    "LIBGL_ALWAYS_SOFTWARE"
)

for var in "${REQUIRED_ENV_VARS[@]}"; do
    if grep -q "$var" "$SETUP_SCRIPT"; then
        test_pass "Environment variable '$var' is set"
    else
        test_fail "Environment variable '$var' is not set"
    fi
done

# Test 7: Check for critical apt packages
echo "[Test 7] Checking for critical apt packages..."
CRITICAL_PACKAGES=(
    "wget"
    "curl"
    "git"
    "libgtk-3-0"
    "libnss3"
)

for pkg in "${CRITICAL_PACKAGES[@]}"; do
    if grep -q "$pkg" "$SETUP_SCRIPT"; then
        test_pass "Package '$pkg' is in dependency list"
    else
        test_fail "Package '$pkg' is missing from dependency list"
    fi
done

# Test 8: Check for VSCode launcher creation
echo "[Test 8] Checking for VSCode launcher creation..."
if grep -q "/usr/local/bin/vscode-launcher" "$SETUP_SCRIPT"; then
    test_pass "VSCode launcher path is defined"
else
    test_fail "VSCode launcher path is missing"
fi

if grep -q "code --no-sandbox" "$SETUP_SCRIPT"; then
    test_pass "VSCode launcher uses --no-sandbox flag"
else
    test_fail "VSCode launcher missing --no-sandbox flag"
fi

# Test 9: Check helper scripts creation
echo "[Test 9] Checking helper scripts..."
if grep -q "/opt/vscode-helpers" "$SETUP_SCRIPT"; then
    test_pass "Helper scripts directory is defined"
else
    test_fail "Helper scripts directory is missing"
fi

if grep -q "fix-permissions.sh" "$SETUP_SCRIPT"; then
    test_pass "fix-permissions.sh helper is created"
else
    test_fail "fix-permissions.sh helper is missing"
fi

if grep -q "check-env.sh" "$SETUP_SCRIPT"; then
    test_pass "check-env.sh helper is created"
else
    test_fail "check-env.sh helper is missing"
fi

# Test 10: Check for root privilege check
echo "[Test 10] Checking for root privilege verification..."
if grep -q 'if.*EUID.*-ne 0' "$SETUP_SCRIPT"; then
    test_pass "Script checks for root privileges"
else
    test_fail "Script doesn't check for root privileges"
fi

# Test 11: Validate quick-start.sh
echo "[Test 11] Validating quick-start.sh..."
QUICKSTART_SCRIPT="$SCRIPT_DIR/quick-start.sh"
if [ -f "$QUICKSTART_SCRIPT" ]; then
    test_pass "quick-start.sh exists"
    if [ -x "$QUICKSTART_SCRIPT" ]; then
        test_pass "quick-start.sh is executable"
    else
        test_fail "quick-start.sh is not executable"
    fi
    if bash -n "$QUICKSTART_SCRIPT" 2>/dev/null; then
        test_pass "quick-start.sh has valid syntax"
    else
        test_fail "quick-start.sh has syntax errors"
    fi
else
    test_fail "quick-start.sh not found"
fi

# Test 12: Validate uninstall.sh
echo "[Test 12] Validating uninstall.sh..."
UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"
if [ -f "$UNINSTALL_SCRIPT" ]; then
    test_pass "uninstall.sh exists"
    if [ -x "$UNINSTALL_SCRIPT" ]; then
        test_pass "uninstall.sh is executable"
    else
        test_fail "uninstall.sh is not executable"
    fi
    if bash -n "$UNINSTALL_SCRIPT" 2>/dev/null; then
        test_pass "uninstall.sh has valid syntax"
    else
        test_fail "uninstall.sh has syntax errors"
    fi
else
    test_fail "uninstall.sh not found"
fi

# Test 13: Check README
echo "[Test 13] Checking README.md..."
README="$SCRIPT_DIR/README.md"
if [ -f "$README" ]; then
    test_pass "README.md exists"
    
    # Check for important sections
    if grep -q "## Installation" "$README"; then
        test_pass "README has Installation section"
    else
        test_fail "README missing Installation section"
    fi
    
    if grep -q "## Troubleshooting" "$README"; then
        test_pass "README has Troubleshooting section"
    else
        test_fail "README missing Troubleshooting section"
    fi
    
    if grep -q "sudo bash setup-vscode.sh" "$README"; then
        test_pass "README includes setup command"
    else
        test_fail "README missing setup command"
    fi
else
    test_fail "README.md not found"
fi

# Test 14: Check for .gitignore
echo "[Test 14] Checking .gitignore..."
if [ -f "$SCRIPT_DIR/.gitignore" ]; then
    test_pass ".gitignore exists"
else
    test_fail ".gitignore not found"
fi

# Test 15: Check for LICENSE
echo "[Test 15] Checking LICENSE..."
if [ -f "$SCRIPT_DIR/LICENSE" ]; then
    test_pass "LICENSE exists"
else
    test_fail "LICENSE not found"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Results Summary                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests:  $TOTAL_TESTS"
echo "Passed:       $PASSED_TESTS"
echo "Failed:       $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed. Please review the output above."
    exit 1
fi
