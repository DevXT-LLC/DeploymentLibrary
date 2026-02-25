# Install Zoom (Windows)
# Downloads and silently installs the latest Zoom Client
$ErrorActionPreference = 'Stop'
Write-Host "Installing Zoom..."

$installerUrl = "https://zoom.us/client/latest/ZoomInstallerFull.msi"
$installerPath = "$env:TEMP\ZoomInstaller.msi"

Write-Host "Downloading Zoom..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

Write-Host "Installing..."
Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/qn" -Wait -NoNewWindow

Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Zoom installed successfully."
