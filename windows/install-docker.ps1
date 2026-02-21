# Install Docker Desktop (Windows)
# Downloads and installs Docker Desktop for Windows
Write-Host "Downloading Docker Desktop..."
$installerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Docker Desktop..."
Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Docker Desktop installed successfully."
Write-Host "A restart may be required to complete the installation."
