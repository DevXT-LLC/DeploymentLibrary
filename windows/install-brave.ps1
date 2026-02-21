# Install Brave Browser (Windows)
# Downloads and silently installs the latest Brave Browser
Write-Host "Downloading Brave Browser..."
$installerUrl = "https://laptop-updates.brave.com/latest/winx64"
$installerPath = "$env:TEMP\BraveBrowserSetup.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Brave Browser..."
Start-Process -FilePath $installerPath -ArgumentList "/silent", "/install" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Brave Browser installed successfully."
