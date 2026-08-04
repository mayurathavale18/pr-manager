# install.ps1 — Windows installer for pr-manager
#
# Usage (PowerShell):
#   irm https://github.com/mayurathavale18/pr-manager/releases/latest/download/install.ps1 | iex
#
# Environment variables (all optional):
#   PRM_VERSION      specific version to install, e.g. "v2.1.0"  (default: latest)
#   PRM_INSTALL_DIR  directory to place the binary                (default: %LocalAppData%\Programs\pr-manager)
#
# Environment variables are used instead of script parameters because a
# script piped into `iex` cannot receive command-line arguments directly.
#
# Example pinning a version:
#   $env:PRM_VERSION = "v2.0.0"
#   irm https://github.com/mayurathavale18/pr-manager/releases/latest/download/install.ps1 | iex
#
# This mirrors install.sh section-for-section so the two stay easy to compare:
#   1. Script hardening      2. Constants      3. Helpers
#   4. Detect architecture   5. Resolve version 6. Construct URL
#   7. Temp dir + cleanup    8. Download        9. Verify checksum
#  10. Extract               11. Install dir    12. Install
#  13. Verify                14. PATH + next steps

# =============================================================================
# 1. SCRIPT HARDENING
#
# $ErrorActionPreference = "Stop" is PowerShell's equivalent of bash's `set -e`:
# any non-terminating error becomes terminating, so the script stops instead
# of silently continuing after a failure.
# =============================================================================
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest   # equivalent of `set -u` — undefined variables error out

# =============================================================================
# 2. CONSTANTS
#
# Kept at the top, same as install.sh, so forking this for another project
# only requires editing this block.
# =============================================================================
$Repo      = "mayurathavale18/pr-manager"
$Binary    = "pr-manager"
$GitHubApi = "https://api.github.com/repos/$Repo/releases/latest"
$GitHubDl  = "https://github.com/$Repo/releases/download"

# Allow overriding via environment variables, mirroring install.sh's
# VERSION / INSTALL_DIR conventions.
$Version    = $env:PRM_VERSION
$InstallDir = $env:PRM_INSTALL_DIR

# =============================================================================
# 3. OUTPUT HELPERS
#
# Write-Host -ForegroundColor is the PowerShell equivalent of ANSI colour
# codes — it works natively in both Windows PowerShell and PowerShell 7,
# without needing an escape-sequence-capable terminal.
# =============================================================================
function Write-Info    { param($Message) Write-Host "[INFO]    $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "[OK]      $Message" -ForegroundColor Green }
function Write-Warn    { param($Message) Write-Host "[WARN]    $Message" -ForegroundColor Yellow }
function Write-Header  { param($Message) Write-Host "`n=== $Message ===`n" -ForegroundColor White }

# Write-Fatal throws instead of calling `exit` directly.  Calling `exit`
# inside a try block can skip the paired `finally` on some PowerShell hosts;
# `throw` is a proper terminating error that always unwinds through
# try/finally first (running our cleanup), then aborts the script with a
# non-zero exit code once it reaches the top with no enclosing catch.
function Write-Fatal {
    param($Message)
    Write-Host "[ERROR]   $Message" -ForegroundColor Red
    throw $Message
}

# =============================================================================
# 4. DETECT ARCHITECTURE
#
# The release pipeline currently only builds a windows-amd64 binary (see the
# `build` job matrix in .github/workflows/release.yml), so this is hardcoded
# to "amd64" rather than detected at runtime like install.sh does for
# Linux/macOS.  Windows-on-ARM64 devices still run the amd64 binary fine via
# Windows' built-in x64 emulation, so this covers every Windows machine today.
#
# If a native windows/arm64 build target is ever added to the matrix, switch
# this back to runtime detection using
# [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
# (falls back to $env:PROCESSOR_ARCHITECTURE on Windows PowerShell 5.1, which
# does not expose RuntimeInformation).
# =============================================================================
$Arch = "amd64"

# =============================================================================
# 5. RESOLVE VERSION
#
# Same approach as install.sh: query the GitHub Releases API for tag_name
# unless the caller pinned one.  Invoke-RestMethod parses JSON natively, so
# no grep/sed equivalent is needed here.
# =============================================================================
if (-not $Version) {
    Write-Info "Querying GitHub for the latest release..."
    try {
        $Release = Invoke-RestMethod -Uri $GitHubApi -Headers @{ "User-Agent" = "pr-manager-installer" }
        $Version = $Release.tag_name
    } catch {
        Write-Fatal "Could not reach GitHub API to determine the latest version: $_"
    }
    if (-not $Version) { Write-Fatal "GitHub API response did not include a tag_name." }
}
Write-Info "Version: $Version"

# =============================================================================
# 6. CONSTRUCT DOWNLOAD URL
#
# Naming convention must match release.yml exactly:
#   pr-manager-<version>-windows-amd64.zip
# =============================================================================
$Archive     = "$Binary-$Version-windows-$Arch.zip"
$ArchiveUrl  = "$GitHubDl/$Version/$Archive"
$ChecksumUrl = "$GitHubDl/$Version/checksums.txt"

Write-Info "Platform: windows/$Arch"
Write-Info "Archive:  $Archive"

# =============================================================================
# 7. TEMP DIR + CLEANUP
#
# New-TemporaryFile only creates files, not directories, so we build a unique
# temp directory manually.  try/finally is PowerShell's equivalent of bash's
# `trap ... EXIT` — it always runs, even if an error further down aborts
# the script (because $ErrorActionPreference = "Stop" turns errors into
# terminating exceptions, which finally still catches).
# =============================================================================
$TmpDir = Join-Path $env:TEMP ("pr-manager-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    # =========================================================================
    # 8. DOWNLOAD ARCHIVE AND CHECKSUMS
    #
    # Invoke-WebRequest is PowerShell's curl/wget equivalent.
    # -UseBasicParsing avoids a dependency on Internet Explorer's DOM parser
    # on older Windows PowerShell versions.
    # =========================================================================
    Write-Header "Downloading"
    $ArchivePath  = Join-Path $TmpDir $Archive
    $ChecksumPath = Join-Path $TmpDir "checksums.txt"

    try {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath -UseBasicParsing
    } catch {
        Write-Fatal "Download failed: $ArchiveUrl"
    }
    try {
        Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumPath -UseBasicParsing
    } catch {
        Write-Fatal "Download failed: $ChecksumUrl"
    }
    Write-Success "Downloaded $Archive"

    # =========================================================================
    # 9. VERIFY CHECKSUM
    #
    # Get-FileHash is the built-in equivalent of sha256sum; no external tool
    # is required on any supported Windows version.
    # =========================================================================
    Write-Header "Verifying checksum"
    $ExpectedLine = Select-String -Path $ChecksumPath -Pattern ([regex]::Escape($Archive))
    if (-not $ExpectedLine) {
        Write-Warn "No checksum entry found for $Archive — skipping verification."
    } else {
        $ExpectedHash = ($ExpectedLine.Line -split '\s+')[0].ToLower()
        $ActualHash   = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLower()
        if ($ExpectedHash -ne $ActualHash) {
            Write-Fatal "Checksum verification failed — the download may be corrupted.`nExpected: $ExpectedHash`nActual:   $ActualHash"
        }
        Write-Success "Checksum verified"
    }

    # =========================================================================
    # 10. EXTRACT BINARY
    #
    # Expand-Archive is built into PowerShell 5.1+ — no external unzip needed.
    # =========================================================================
    Write-Header "Extracting"
    Expand-Archive -Path $ArchivePath -DestinationPath $TmpDir -Force
    $ExtractedBinary = Join-Path $TmpDir "$Binary.exe"
    if (-not (Test-Path $ExtractedBinary)) {
        Write-Fatal "Expected binary not found after extraction: $ExtractedBinary"
    }
    Write-Success "Extracted $Binary.exe"

    # =========================================================================
    # 11. DETERMINE INSTALL DIRECTORY
    #
    # Windows has no universal equivalent of /usr/local/bin.  The convention
    # used by winget, scoop-installed tools, and most Go CLI installers is a
    # per-user directory under %LocalAppData%, which never requires admin
    # rights and is writable out of the box.
    # =========================================================================
    if (-not $InstallDir) {
        $InstallDir = Join-Path $env:LocalAppData "Programs\pr-manager"
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

    # =========================================================================
    # 12. INSTALL BINARY
    # =========================================================================
    Write-Header "Installing"
    $DestPath = Join-Path $InstallDir "$Binary.exe"
    Copy-Item -Path $ExtractedBinary -Destination $DestPath -Force
    Write-Success "Installed to $DestPath"

    # =========================================================================
    # 13. VERIFY INSTALLATION
    # =========================================================================
    try {
        $InstalledVersion = & $DestPath --version 2>&1
        Write-Success "Installation verified: $InstalledVersion"
    } catch {
        Write-Warn "Could not execute $DestPath to verify the installation."
    }

    # =========================================================================
    # 14. ADD TO PATH (PERSISTENT, USER SCOPE) + NEXT STEPS
    #
    # SetEnvironmentVariable with the "User" scope persists across sessions
    # by writing to the registry, without requiring an admin prompt — the
    # Windows equivalent of appending to ~/.bashrc.
    # =========================================================================
    Write-Header "Configuring PATH"
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
        Write-Info "Added $InstallDir to your user PATH."
        Write-Warn "Restart your terminal (or run 'refreshenv' if using Chocolatey) for PATH changes to take effect."
    } else {
        Write-Info "$InstallDir is already on your PATH."
    }

    Write-Host "`nDone.  Run:  $Binary --help`n" -ForegroundColor Green
}
finally {
    # =========================================================================
    # Cleanup — always runs, mirroring install.sh's `trap ... EXIT`.
    # =========================================================================
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
