# Uninstall ezlocalai (Windows)
$ErrorActionPreference = "Stop"

$InstallDir = if ($env:EZLOCALAI_INSTALL_DIR) { $env:EZLOCALAI_INSTALL_DIR } else { "C:\ezlocalai" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Uninstalling ezlocalai" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Stop any running containers
try {
    & docker stop ezlocalai 2>$null
    & docker rm ezlocalai 2>$null
} catch { }

# Stop via CLI if possible
$VenvDir = Join-Path $InstallDir ".venv"
if (Test-Path $VenvDir) {
    try {
        . (Join-Path $VenvDir "Scripts\Activate.ps1")
        Set-Location $InstallDir
        & ezlocalai stop 2>$null
    } catch { }
}

# Remove installation directory
if (Test-Path $InstallDir) {
    Write-Host "Removing installation directory: $InstallDir"
    Remove-Item -Recurse -Force $InstallDir
}

Write-Host ""
Write-Host "ezlocalai has been uninstalled."
Write-Host "Note: Docker images (if any) were not removed. Run 'docker rmi ezlocalai:cuda' to remove them."
