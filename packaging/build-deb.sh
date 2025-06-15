#!/usr/bin/env bash

set -e

# Configuration
PACKAGE_NAME="pr-script"
VERSION="1.0.0"
ARCH="all"
BUILD_DIR="build"
DEB_DIR="${BUILD_DIR}/${PACKAGE_NAME}_${VERSION}_${ARCH}"

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

# Clean previous builds
print_status $BLUE "Cleaning previous builds..."
rm -rf "${BUILD_DIR}"

# Create directory structure
print_status $BLUE "Creating directory structure..."
mkdir -p "${DEB_DIR}/DEBIAN"
mkdir -p "${DEB_DIR}/usr/bin"
mkdir -p "${DEB_DIR}/usr/share/doc/${PACKAGE_NAME}"
mkdir -p "${DEB_DIR}/usr/share/man/man1"

# Copy files
print_status $BLUE "📋 Copying files..."

# Copy main script
cp "../src/pr-script.sh" "${DEB_DIR}/usr/bin/pr-script"
chmod +x "${DEB_DIR}/usr/bin/pr-script"

# Copy control files
cp "debian/DEBIAN/control" "${DEB_DIR}/DEBIAN/"
cp "debian/DEBIAN/postinst" "${DEB_DIR}/DEBIAN/"
cp "debian/DEBIAN/prerm" "${DEB_DIR}/DEBIAN/"
cp "debian/DEBIAN/postrm" "${DEB_DIR}/DEBIAN/"

# Set permissions for control files
chmod 755 "${DEB_DIR}/DEBIAN/postinst"
chmod 755 "${DEB_DIR}/DEBIAN/prerm"
chmod 755 "${DEB_DIR}/DEBIAN/postrm"

# Copy documentation
cp "../README.md" "${DEB_DIR}/usr/share/doc/${PACKAGE_NAME}/"
cp "../LICENSE" "${DEB_DIR}/usr/share/doc/${PACKAGE_NAME}/" 2>/dev/null || echo "LICENSE file not found, skipping..."

# Create changelog
cat > "${DEB_DIR}/usr/share/doc/${PACKAGE_NAME}/changelog" << EOF
pr-script (${VERSION}) stable; urgency=medium

  * Initial release
  * GitHub PR review and merge automation
  * Interactive and auto modes
  * Multiple merge methods support
  * Comprehensive safety checks

 -- Your Name <your.email@example.com>  $(date -R)
EOF

# Create man page
print_status $BLUE "📖 Creating man page..."
cat > "${BUILD_DIR}/pr-script.1" << 'EOF'
.TH PR-SCRIPT 1 "$(date +%Y-%m-%d)" "1.0.0" "User Commands"
.SH NAME
pr-script \- GitHub PR review and merge automation tool
.SH SYNOPSIS
.B pr-script
[\fICOMMAND\fR] \fIPR_NUMBER\fR [\fIOPTIONS\fR]
.SH DESCRIPTION
A comprehensive bash script for reviewing and merging GitHub Pull Requests using the GitHub CLI.
.SH COMMANDS
.TP
.B review \fIPR_NUMBER\fR
Review and approve the PR
.TP
.B merge \fIPR_NUMBER\fR
Merge the PR with safety checks
.TP
.B full \fIPR_NUMBER\fR
Review and merge the PR (default)
.SH OPTIONS
.TP
.B \-a, \-\-auto
Enable auto mode (skip interactive prompts)
.TP
.B \-v, \-\-verbose
Enable verbose output with detailed logs
.TP
.B \-m, \-\-merge\-method \fIMETHOD\fR
Set merge method (auto, merge, squash, rebase)
.TP
.B \-h, \-\-help
Show help message
.SH EXAMPLES
.TP
pr-script 123
Review and merge PR #123 (interactive)
.TP
pr-script merge 123 \-a \-m squash
Auto squash merge PR #123
.SH AUTHOR
Your Name <your.email@example.com>
.SH SEE ALSO
gh(1), git(1)
EOF

# Compress man page
gzip -9c "${BUILD_DIR}/pr-script.1" > "${DEB_DIR}/usr/share/man/man1/pr-script.1.gz"

# Update file sizes in control file
print_status $BLUE "📊 Calculating package size..."
INSTALLED_SIZE=$(du -sk "${DEB_DIR}" | cut -f1)
sed -i "/^Installed-Size:/d" "${DEB_DIR}/DEBIAN/control"
echo "Installed-Size: ${INSTALLED_SIZE}" >> "${DEB_DIR}/DEBIAN/control"

# Build the package - FIXED SECTION
print_status $BLUE "🔨 Building .deb package..."
TEMP_DEB_PATH="${BUILD_DIR}/temp_${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
FINAL_DEB_PATH="${BUILD_DIR}/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

# Build to a temporary location first
fakeroot dpkg-deb --build "${DEB_DIR}" "${TEMP_DEB_PATH}"

# Move to final location with correct name
mv "${TEMP_DEB_PATH}" "${FINAL_DEB_PATH}"

print_status $GREEN "✅ Successfully created: ${FINAL_DEB_PATH}"

# Test the package
print_status $BLUE "🧪 Testing package integrity..."
if dpkg-deb --info "${FINAL_DEB_PATH}" > /dev/null; then
    print_status $GREEN "✅ Package integrity test passed"
else
    print_status $RED "❌ Package integrity test failed"
    exit 1
fi

# Show package info
print_status $BLUE "📦 Package Information:"
dpkg-deb --info "${FINAL_DEB_PATH}"

print_status $GREEN "🎉 Build completed successfully!"
print_status $YELLOW "📁 Package location: ${FINAL_DEB_PATH}"
