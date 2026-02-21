# Install Visual Studio Code (Windows)
# Downloads and silently installs the latest VS Code
Write-Host "Downloading Visual Studio Code..."
$installerUrl = "https://update.code.visualstudio.com/latest/win32-x64/stable"
$installerPath = "$env:TEMP\VSCodeSetup.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Visual Studio Code..."
Start-Process -FilePath $installerPath -ArgumentList "/verysilent", "/norestart", "/mergetasks=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Visual Studio Code installed successfully."
