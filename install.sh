#!/usr/bin/env bash
# install.sh — installer for pr-manager
#
# Usage:
#   curl -fsSL https://github.com/mayurathavale18/pr-manager/releases/latest/download/install.sh | sh
#
# Environment variables (all optional):
#   VERSION      — specific version to install, e.g. "v2.1.0"  (default: latest)
#   INSTALL_DIR  — directory to place the binary               (default: auto)
#
# The script never requires sudo by default.  It installs to /usr/local/bin
# when run as root, and to ~/.local/bin otherwise.  Set INSTALL_DIR to
# override both.

# =============================================================================
# 1. SCRIPT HARDENING
#
# These three lines together catch almost every class of silent failure:
#
#   set -e          exit immediately when any command returns non-zero
#   set -u          treat unset variables as errors (catches typos)
#   set -o pipefail make a pipeline fail if *any* stage fails, not just the last
#
# Without pipefail, "curl ... | tar ..." succeeds even if curl fails,
# because tar exits 0 on empty input.
# =============================================================================
set -euo pipefail

# =============================================================================
# 2. CONSTANTS
#
# Keep all project-specific values at the top so the script is easy to fork
# for a different project by changing only this section.
# =============================================================================
REPO="mayurathavale18/pr-manager"
BINARY="pr-manager"
GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"
GITHUB_DL="https://github.com/${REPO}/releases/download"

# =============================================================================
# 3. COLOUR HELPERS
#
# tput is the portable way to check terminal capability.  If stdout is not
# a terminal (e.g. piped into a log file), colours are disabled automatically.
# =============================================================================
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
fi

info()    { printf "%s[INFO]%s    %s\n"    "$BLUE"   "$RESET" "$*"; }
success() { printf "%s[OK]%s      %s\n"    "$GREEN"  "$RESET" "$*"; }
warn()    { printf "%s[WARN]%s    %s\n"    "$YELLOW" "$RESET" "$*" >&2; }
fatal()   { printf "%s[ERROR]%s   %s\n"    "$RED"    "$RESET" "$*" >&2; exit 1; }
header()  { printf "\n%s=== %s ===%s\n\n" "$BOLD"   "$*"     "$RESET"; }

# =============================================================================
# 4. DETECT DOWNLOADER
#
# Most systems have curl; many Linux servers have only wget.
# Normalise both into a single download() function so the rest of the script
# never needs to branch on which tool is available.
# =============================================================================
if command -v curl >/dev/null 2>&1; then
  # -f  fail silently on HTTP errors (returns exit code 22)
  # -s  silent (no progress bar)
  # -S  show error even when silent
  # -L  follow redirects (essential for GitHub release assets)
  download() { curl -fsSL "$1" -o "$2"; }
  download_stdout() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  download() { wget -q "$1" -O "$2"; }
  download_stdout() { wget -q "$1" -O -; }
else
  fatal "Neither curl nor wget found.  Install one and retry."
fi

# =============================================================================
# 5. DETECT OPERATING SYSTEM
#
# uname -s returns the kernel name.  We lowercase it and map to the GOOS
# values used when naming the release archives.
# =============================================================================
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux)   OS="linux"  ;;
  darwin)  OS="darwin" ;;
  mingw*|msys*|cygwin*) OS="windows" ;;
  *)       fatal "Unsupported OS: $(uname -s)" ;;
esac

# =============================================================================
# 6. DETECT ARCHITECTURE
#
# uname -m returns the hardware class.  We map it to GOARCH naming:
#   x86_64  → amd64    (most desktops / cloud VMs)
#   aarch64 → arm64    (Apple Silicon, AWS Graviton, Raspberry Pi 4+)
#   armv7l  → arm      (older Raspberry Pi — only add if you ship this target)
# =============================================================================
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)           ARCH="amd64" ;;
  aarch64|arm64)    ARCH="arm64" ;;
  *)                fatal "Unsupported architecture: $(uname -m)" ;;
esac

# =============================================================================
# 7. RESOLVE VERSION
#
# The caller can pin a version:
#   VERSION=v2.0.0 curl ... | sh
#
# Otherwise we query the GitHub Releases API.  The response is JSON; we
# extract tag_name with a grep+sed pipeline instead of requiring jq, because
# jq is not available everywhere.
#
# The grep pattern matches:  "tag_name": "v2.1.0"
# The sed extracts just:     v2.1.0
# =============================================================================
if [ -z "${VERSION:-}" ]; then
  info "Querying GitHub for the latest release..."
  VERSION=$(download_stdout "$GITHUB_API" \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  [ -n "$VERSION" ] || fatal "Could not determine latest version from GitHub API."
fi
info "Version: ${BOLD}${VERSION}${RESET}"

# =============================================================================
# 8. CONSTRUCT DOWNLOAD URL
#
# Archive naming convention (must match exactly what release.yml produces):
#   pr-manager-<version>-<os>-<arch>.tar.gz   (Linux / macOS)
#   pr-manager-<version>-<os>-<arch>.zip      (Windows)
# =============================================================================
if [ "$OS" = "windows" ]; then
  ARCHIVE="${BINARY}-${VERSION}-${OS}-${ARCH}.zip"
else
  ARCHIVE="${BINARY}-${VERSION}-${OS}-${ARCH}.tar.gz"
fi

ARCHIVE_URL="${GITHUB_DL}/${VERSION}/${ARCHIVE}"
CHECKSUM_URL="${GITHUB_DL}/${VERSION}/checksums.txt"

info "Platform: ${OS}/${ARCH}"
info "Archive:  ${ARCHIVE}"

# =============================================================================
# 9. TEMP DIR + CLEANUP TRAP
#
# mktemp -d creates a unique temporary directory.
# The trap ensures it is deleted when the script exits — whether that is a
# clean exit, an error exit (set -e), or a signal (Ctrl-C).
#
# This is the correct pattern; never leave temp files behind.
# =============================================================================
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# =============================================================================
# 10. DOWNLOAD ARCHIVE AND CHECKSUMS
# =============================================================================
header "Downloading"
download "$ARCHIVE_URL"  "${TMP_DIR}/${ARCHIVE}"   || fatal "Download failed: ${ARCHIVE_URL}"
download "$CHECKSUM_URL" "${TMP_DIR}/checksums.txt" || fatal "Download failed: ${CHECKSUM_URL}"
success "Downloaded ${ARCHIVE}"

# =============================================================================
# 11. VERIFY CHECKSUM
#
# We change into TMP_DIR so that sha256sum resolves filenames relative to the
# same directory as it recorded them.  The grep limits verification to only
# the archive we downloaded, ignoring other assets in checksums.txt.
# =============================================================================
header "Verifying checksum"
if command -v sha256sum >/dev/null 2>&1; then
  # Linux / most Unix
  (cd "$TMP_DIR" && grep "$ARCHIVE" checksums.txt | sha256sum --check --status) \
    || fatal "Checksum verification failed — the download may be corrupted."
elif command -v shasum >/dev/null 2>&1; then
  # macOS ships shasum instead of sha256sum
  (cd "$TMP_DIR" && grep "$ARCHIVE" checksums.txt | shasum -a 256 --check --status) \
    || fatal "Checksum verification failed — the download may be corrupted."
else
  warn "sha256sum / shasum not found — skipping checksum verification."
fi
success "Checksum verified"

# =============================================================================
# 12. EXTRACT BINARY
# =============================================================================
header "Extracting"
if [ "$OS" = "windows" ]; then
  # unzip is standard on Windows environments (Git Bash, MSYS2, Cygwin)
  command -v unzip >/dev/null 2>&1 || fatal "unzip not found."
  unzip -q "${TMP_DIR}/${ARCHIVE}" -d "$TMP_DIR"
else
  # -x  extract
  # -z  decompress with gzip
  # -f  read from file
  # -C  change to directory before extracting
  tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR"
fi
success "Extracted ${BINARY}"

# =============================================================================
# 13. DETERMINE INSTALL DIRECTORY
#
# Priority:
#   1. $INSTALL_DIR env var (user-controlled)
#   2. /usr/local/bin  — when running as root (system-wide)
#   3. ~/.local/bin    — when running as a regular user
#
# Option 3 is the most important: the script should NEVER require sudo
# for a regular user.  ~/.local/bin is the XDG standard for user binaries.
# =============================================================================
if [ -n "${INSTALL_DIR:-}" ]; then
  BIN_DIR="$INSTALL_DIR"
elif [ "$(id -u)" -eq 0 ]; then
  BIN_DIR="/usr/local/bin"
else
  BIN_DIR="${HOME}/.local/bin"
fi

mkdir -p "$BIN_DIR"

# =============================================================================
# 14. INSTALL BINARY
# =============================================================================
header "Installing"
EXT=""
[ "$OS" = "windows" ] && EXT=".exe"

mv "${TMP_DIR}/${BINARY}${EXT}" "${BIN_DIR}/${BINARY}${EXT}"
chmod +x "${BIN_DIR}/${BINARY}${EXT}"
success "Installed to ${BIN_DIR}/${BINARY}${EXT}"

# =============================================================================
# 15. VERIFY INSTALLATION
# =============================================================================
if command -v "${BINARY}" >/dev/null 2>&1; then
  INSTALLED_VERSION=$("${BINARY}" --version 2>&1 || true)
  success "Installation verified: ${INSTALLED_VERSION}"
else
  # Binary installed fine but isn't on PATH yet — this is expected for
  # ~/.local/bin on a fresh system.
  warn "${BINARY} is not on your PATH yet."
fi

# =============================================================================
# 16. PRINT NEXT STEPS
#
# Always tell the user what to do next.  If we installed to ~/.local/bin and
# it's not on their PATH, the binary appears broken even though it isn't.
# =============================================================================
printf "\n"
if [ "$BIN_DIR" = "${HOME}/.local/bin" ]; then
  case "${SHELL:-}" in
    */zsh)  PROFILE="${HOME}/.zshrc"  ;;
    */fish) PROFILE="${HOME}/.config/fish/config.fish" ;;
    *)      PROFILE="${HOME}/.bashrc" ;;
  esac

  # Only print the PATH hint if it actually isn't on the PATH.
  if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    printf "%s[NOTE]%s    Add %s to your PATH:\n\n" "$YELLOW" "$RESET" "$BIN_DIR"
    printf "    echo 'export PATH=\"%s:\$PATH\"' >> %s\n" "$BIN_DIR" "$PROFILE"
    printf "    source %s\n\n" "$PROFILE"
  fi
fi

printf "%sDone.%s  Run:  %s --help\n\n" "$GREEN" "$RESET" "$BINARY"
