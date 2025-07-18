#!/usr/bin/env bash

set -e

# Configuration
PACKAGE_NAME="pr-script"
VERSION="1.0.0"
BUILD_DIR="build"
BINARY_DIR="${BUILD_DIR}/binary"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_status $BLUE "🔧 Creating binary release..."

# Create binary directory
mkdir -p "${BINARY_DIR}"

# Copy script
cp "../src/pr-script.sh" "${BINARY_DIR}/pr-script"
chmod +x "${BINARY_DIR}/pr-script"

# Create install script
cat > "${BINARY_DIR}/install.sh" << 'EOF'
#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_status $BLUE "Installing pr-script..."

# Check if running as root for system-wide install
if [ "$EUID" -eq 0 ]; then
    INSTALL_DIR="/usr/local/bin"
    DOC_DIR="/usr/local/share/doc/pr-script"
    print_status $BLUE "Installing system-wide to ${INSTALL_DIR}"
else
    INSTALL_DIR="$HOME/.local/bin"
    DOC_DIR="$HOME/.local/share/doc/pr-script"
    print_status $BLUE "Installing to user directory ${INSTALL_DIR}"
    
    # Create directories if they don't exist
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${DOC_DIR}"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        print_status $YELLOW "Added ~/.local/bin to PATH in ~/.bashrc"
        print_status $YELLOW "Please run: source ~/.bashrc or restart your terminal"
    fi
fi

# Install the script
cp pr-script "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}/pr-script"

# Install documentation
mkdir -p "${DOC_DIR}"
cp README.md "${DOC_DIR}/" 2>/dev/null || true
cp LICENSE "${DOC_DIR}/" 2>/dev/null || true

# Check dependencies
print_status $BLUE "🔍 Checking dependencies..."

if ! command -v git &> /dev/null; then
    print_status $RED "❌ git is not installed!"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    print_status $YELLOW "⚠️  GitHub CLI (gh) is not installed!"
    print_status $BLUE "Installation instructions:"
    
    if command -v apt &> /dev/null; then
        print_status $BLUE "   sudo apt update && sudo apt install gh"
    elif command -v pacman &> /dev/null; then
        print_status $BLUE "   sudo pacman -S github-cli"
    elif command -v yum &> /dev/null; then
        print_status $BLUE "   sudo yum install gh"
    else
        print_status $BLUE "   Visit: https://cli.github.com/manual/installation"
    fi
    
    print_status $BLUE "After installation, authenticate with: gh auth login"
else
    print_status $GREEN "GitHub CLI found"
    
    # Check if authenticated
    if gh auth status &> /dev/null; then
        print_status $GREEN "GitHub CLI is authenticated"
    else
        print_status $YELLOW "Please authenticate with: gh auth login"
    fi
fi

print_status $GREEN "pr-script installed successfully!"
print_status $BLUE "Usage: pr-script --help"
print_status $BLUE "Example: pr-script 123"

if [ "$EUID" -ne 0 ]; then
    print_status $YELLOW "Note: Installed to user directory. Make sure ~/.local/bin is in your PATH"
fi
EOF

chmod +x "${BINARY_DIR}/install.sh"

# Create uninstall script
cat > "${BINARY_DIR}/uninstall.sh" << 'EOF'
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_status $BLUE "🗑️  Uninstalling pr-script..."

# Check installation locations
SYSTEM_INSTALL="/usr/local/bin/pr-script"
USER_INSTALL="$HOME/.local/bin/pr-script"

if [ -f "$SYSTEM_INSTALL" ]; then
    if [ "$EUID" -eq 0 ]; then
        rm -f "$SYSTEM_INSTALL"
        rm -rf "/usr/local/share/doc/pr-script"
        print_status $GREEN "System-wide installation removed"
    else
        print_status $RED "❌ System-wide installation found, but not running as root"
        print_status $BLUE "Run with sudo to remove system-wide installation"
        exit 1
    fi
elif [ -f "$USER_INSTALL" ]; then
    rm -f "$USER_INSTALL"
    rm -rf "$HOME/.local/share/doc/pr-script"
    print_status $GREEN "User installation removed"
else
    print_status $YELLOW "⚠️  pr-script not found in standard locations"
fi

print_status $GREEN "Uninstall completed!"
EOF

chmod +x "${BINARY_DIR}/uninstall.sh"

# Copy documentation
cp "../README.md" "${BINARY_DIR}/" 2>/dev/null || true
cp "../LICENSE" "${BINARY_DIR}/" 2>/dev/null || true

# Create tarball
print_status $BLUE "📦 Creating tarball..."
cd "${BINARY_DIR}"
tar -czf "../${PACKAGE_NAME}-${VERSION}-linux.tar.gz" .
cd - > /dev/null

print_status $GREEN "Binary release created: ${BUILD_DIR}/${PACKAGE_NAME}-${VERSION}-linux.tar.gz"

# Create checksums
print_status $BLUE "Creating checksums..."
cd "${BUILD_DIR}"
sha256sum "${PACKAGE_NAME}-${VERSION}-linux.tar.gz" > "${PACKAGE_NAME}-${VERSION}-linux.tar.gz.sha256"
md5sum "${PACKAGE_NAME}-${VERSION}-linux.tar.gz" > "${PACKAGE_NAME}-${VERSION}-linux.tar.gz.md5"
cd - > /dev/null

print_status $GREEN "Binary release completed!"
print_status $YELLOW "Files created:"
print_status $YELLOW "   - ${BUILD_DIR}/${PACKAGE_NAME}-${VERSION}-linux.tar.gz"
print_status $YELLOW "   - ${BUILD_DIR}/${PACKAGE_NAME}-${VERSION}-linux.tar.gz.sha256"
print_status $YELLOW "   - ${BUILD_DIR}/${PACKAGE_NAME}-${VERSION}-linux.tar.gz.md5"

