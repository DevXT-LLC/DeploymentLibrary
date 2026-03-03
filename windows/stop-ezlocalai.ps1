# Stop ezlocalai server (Windows)
$ErrorActionPreference = "Stop"

$InstallDir = if ($env:EZLOCALAI_INSTALL_DIR) { $env:EZLOCALAI_INSTALL_DIR } else { "C:\ezlocalai" }
$VenvDir = Join-Path $InstallDir ".venv"

Write-Host "Stopping ezlocalai..."

if (-not (Test-Path $VenvDir)) {
    Write-Host "ERROR: ezlocalai venv not found at $VenvDir" -ForegroundColor Red
    exit 1
}

. (Join-Path $VenvDir "Scripts\Activate.ps1")
Set-Location $InstallDir
& ezlocalai stop
Write-Host "ezlocalai stopped."
