# Install Slack (Windows)
# Downloads and silently installs the latest Slack desktop client
$ErrorActionPreference = 'Stop'
Write-Host "Installing Slack..."

$installerUrl = "https://slack.com/ssb/download-win64-msi"
$installerPath = "$env:TEMP\Slack.msi"

Write-Host "Downloading Slack..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

Write-Host "Installing..."
Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/qn" -Wait -NoNewWindow

Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Slack installed successfully."
