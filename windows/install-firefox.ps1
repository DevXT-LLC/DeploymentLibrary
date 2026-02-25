# Install Firefox (Windows)
# Downloads and silently installs the latest Mozilla Firefox
$ErrorActionPreference = 'Stop'
Write-Host "Installing Firefox..."

$installerUrl = "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US"
$installerPath = "$env:TEMP\firefox.msi"

Write-Host "Downloading Firefox..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

Write-Host "Installing..."
Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/qn", "DESKTOP_SHORTCUT=true" -Wait -NoNewWindow

Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Firefox installed successfully."
