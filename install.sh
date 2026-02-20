#!/usr/bin/env bash

set -euo pipefail

REPO="mayurathavale18/pr-manager"
BINARY="pr-manager"
GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"
GITHUB_DL="https://github.com/${REPO}/releases/download"
 
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

if command -v curl >/dev/null 2>&1; then
  download() { curl -fsSL "$1" -o "$2"; }
  download_stdout() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  download() { wget -q "$1" -O "$2"; }
  download_stdout() { wget -q "$1" -O -; }
else
  fatal "Neither curl nor wget found.  Install one and retry."
fi
 
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux)   OS="linux"  ;;
  darwin)  OS="darwin" ;;
  mingw*|msys*|cygwin*) OS="windows" ;;
  *)       fatal "Unsupported OS: $(uname -s)" ;;
esac

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)           ARCH="amd64" ;;
  aarch64|arm64)    ARCH="arm64" ;;
  *)                fatal "Unsupported architecture: $(uname -m)" ;;
esac

if [ -z "${VERSION:-}" ]; then
  info "Querying GitHub for the latest release..."
  VERSION=$(download_stdout "$GITHUB_API" \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  [ -n "$VERSION" ] || fatal "Could not determine latest version from GitHub API."
fi
info "Version: ${BOLD}${VERSION}${RESET}"
 
if [ "$OS" = "windows" ]; then
  ARCHIVE="${BINARY}-${VERSION}-${OS}-${ARCH}.zip"
else
  ARCHIVE="${BINARY}-${VERSION}-${OS}-${ARCH}.tar.gz"
fi
 
ARCHIVE_URL="${GITHUB_DL}/${VERSION}/${ARCHIVE}"
CHECKSUM_URL="${GITHUB_DL}/${VERSION}/checksums.txt"
 
info "Platform: ${OS}/${ARCH}"
info "Archive:  ${ARCHIVE}"
 
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
header "Downloading"
download "$ARCHIVE_URL"  "${TMP_DIR}/${ARCHIVE}"   || fatal "Download failed: ${ARCHIVE_URL}"
download "$CHECKSUM_URL" "${TMP_DIR}/checksums.txt" || fatal "Download failed: ${CHECKSUM_URL}"
success "Downloaded ${ARCHIVE}"
 
header "Verifying checksum"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$TMP_DIR" && grep "$ARCHIVE" checksums.txt | sha256sum --check --status) \
    || fatal "Checksum verification failed — the download may be corrupted."
elif command -v shasum >/dev/null 2>&1; then
  (cd "$TMP_DIR" && grep "$ARCHIVE" checksums.txt | shasum -a 256 --check --status) \
    || fatal "Checksum verification failed — the download may be corrupted."
else
  warn "sha256sum / shasum not found — skipping checksum verification."
fi
success "Checksum verified"
 
header "Extracting"
if [ "$OS" = "windows" ]; then
  command -v unzip >/dev/null 2>&1 || fatal "unzip not found."
  unzip -q "${TMP_DIR}/${ARCHIVE}" -d "$TMP_DIR"
else
  tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR"
fi
success "Extracted ${BINARY}"
 
if [ -n "${INSTALL_DIR:-}" ]; then
  BIN_DIR="$INSTALL_DIR"
elif [ "$(id -u)" -eq 0 ]; then
  BIN_DIR="/usr/local/bin"
else
  BIN_DIR="${HOME}/.local/bin"
fi
 
mkdir -p "$BIN_DIR"
 
header "Installing"
EXT=""
[ "$OS" = "windows" ] && EXT=".exe"
 
mv "${TMP_DIR}/${BINARY}${EXT}" "${BIN_DIR}/${BINARY}${EXT}"
chmod +x "${BIN_DIR}/${BINARY}${EXT}"
success "Installed to ${BIN_DIR}/${BINARY}${EXT}"
 
if command -v "${BINARY}" >/dev/null 2>&1; then
  INSTALLED_VERSION=$("${BINARY}" --version 2>&1 || true)
  success "Installation verified: ${INSTALLED_VERSION}"
else
  # Binary installed fine but isn't on PATH yet — this is expected for
  # ~/.local/bin on a fresh system.
  warn "${BINARY} is not on your PATH yet."
fi

printf "\n"
if [ "$BIN_DIR" = "${HOME}/.local/bin" ]; then
  case "${SHELL:-}" in
    */zsh)  PROFILE="${HOME}/.zshrc"  ;;
    */fish) PROFILE="${HOME}/.config/fish/config.fish" ;;
    *)      PROFILE="${HOME}/.bashrc" ;;
  esac
  if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    printf "%s[NOTE]%s    Add %s to your PATH:\n\n" "$YELLOW" "$RESET" "$BIN_DIR"
    printf "    echo 'export PATH=\"%s:\$PATH\"' >> %s\n" "$BIN_DIR" "$PROFILE"
    printf "    source %s\n\n" "$PROFILE"
  fi
fi
 
printf "%sDone.%s  Run:  %s --help\n\n" "$GREEN" "$RESET" "$BINARY"
