# Check ezlocalai server status (Windows)
$ErrorActionPreference = "Stop"

$InstallDir = if ($env:EZLOCALAI_INSTALL_DIR) { $env:EZLOCALAI_INSTALL_DIR } else { "C:\ezlocalai" }
$VenvDir = Join-Path $InstallDir ".venv"

Write-Host "Checking ezlocalai status..."

if (-not (Test-Path $VenvDir)) {
    Write-Host "ezlocalai is not installed at $InstallDir" -ForegroundColor Red
    exit 1
}

. (Join-Path $VenvDir "Scripts\Activate.ps1")
Set-Location $InstallDir
& ezlocalai status
