# ---- qpm Build Script -------------------------------------------------------
# Usage:
#   ./build.ps1              - builds Windows binary
#   ./build.ps1 -Target all  - builds all platforms
#   ./build.ps1 -Target linux
#   ./build.ps1 -Target mac
#   ./build.ps1 -Target mac-arm
#   ./build.ps1 -Clean       - removes bin/ directory
# -----------------------------------------------------------------------------

param(
    [string]$Target = "win",
    [switch]$Clean
)

# ---- Config -----------------------------------------------------------------

$BinDir     = "bin"
$QpmSrc     = "./cmd/qpm"
$Version    = "0.1.0"

# ---- Helpers ----------------------------------------------------------------

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host " [OK] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host " [FAIL] $Message" -ForegroundColor Red
}

function Build-Binary {
    param(
        [string]$OS,
        [string]$Arch,
        [string]$OutFile
    )

    $env:GOOS   = $OS
    $env:GOARCH = $Arch

    Write-Host "  Building qpm..." -ForegroundColor Gray
    go build -o "$BinDir/$OutFile" $QpmSrc
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed to build qpm for $OS/$Arch"
        return $false
    }
    Write-Success "qpm -> $BinDir/$OutFile"

    return $true
}

# ---- Clean ------------------------------------------------------------------

if ($Clean) {
    Write-Header "Cleaning bin/"
    if (Test-Path $BinDir) {
        Remove-Item -Recurse -Force $BinDir
        Write-Success "bin/ removed"
    } else {
        Write-Host "  bin/ does not exist, nothing to clean" -ForegroundColor Gray
    }
    exit 0
}

# ---- Setup ------------------------------------------------------------------

Write-Header "qpm Build v$Version"

if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
    Write-Host "  Created bin/" -ForegroundColor Gray
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Fail "Go is not installed or not in PATH"
    exit 1
}

$GoVersion = go version
Write-Host "  Using $GoVersion" -ForegroundColor Gray

# ---- Builds -----------------------------------------------------------------

$Success = $true

switch ($Target.ToLower()) {

    "win" {
        Write-Header "Building for Windows (x64)"
        $Result = Build-Binary -OS "windows" -Arch "amd64" `
            -OutFile "qpm.exe"
        if (-not $Result) { $Success = $false }
    }

    "linux" {
        Write-Header "Building for Linux (x64)"
        $Result = Build-Binary -OS "linux" -Arch "amd64" `
            -OutFile "qpm-linux"
        if (-not $Result) { $Success = $false }
    }

    "mac" {
        Write-Header "Building for macOS (Intel x64)"
        $Result = Build-Binary -OS "darwin" -Arch "amd64" `
            -OutFile "qpm-macos-intel"
        if (-not $Result) { $Success = $false }
    }

    "mac-arm" {
        Write-Header "Building for macOS (Apple Silicon arm64)"
        $Result = Build-Binary -OS "darwin" -Arch "arm64" `
            -OutFile "qpm-macos-arm"
        if (-not $Result) { $Success = $false }
    }

    "all" {
        Write-Header "Building for all platforms"

        Write-Host ""
        Write-Host "  Windows x64" -ForegroundColor Yellow
        $r1 = Build-Binary -OS "windows" -Arch "amd64" `
            -OutFile "qpm.exe"

        Write-Host ""
        Write-Host "  Linux x64" -ForegroundColor Yellow
        $r2 = Build-Binary -OS "linux" -Arch "amd64" `
            -OutFile "qpm-linux"

        Write-Host ""
        Write-Host "  macOS Intel x64" -ForegroundColor Yellow
        $r3 = Build-Binary -OS "darwin" -Arch "amd64" `
            -OutFile "qpm-macos-intel"

        Write-Host ""
        Write-Host "  macOS Apple Silicon arm64" -ForegroundColor Yellow
        $r4 = Build-Binary -OS "darwin" -Arch "arm64" `
            -OutFile "qpm-macos-arm"

        if (-not ($r1 -and $r2 -and $r3 -and $r4)) { $Success = $false }
    }

    default {
        Write-Fail "Unknown target: $Target"
        Write-Host "  Valid targets: win, linux, mac, mac-arm, all" -ForegroundColor Gray
        exit 1
    }
}

# ---- Reset Go env -----------------------------------------------------------

$env:GOOS   = ""
$env:GOARCH = ""

# ---- Summary ----------------------------------------------------------------

Write-Header "Build Summary"

if ($Success) {
    Write-Host ""
    Write-Host "  All binaries built successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Output files:" -ForegroundColor Gray
    Get-ChildItem $BinDir | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "    $($_.Name) ($size MB)" -ForegroundColor White
    }
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Fail "Build completed with errors"
    Write-Host ""
    exit 1
}
