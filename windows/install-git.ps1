# Install Git (Windows)
# Downloads and silently installs the latest Git for Windows
Write-Host "Downloading Git for Windows..."
$apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$asset = $release.assets | Where-Object { $_.name -match "Git-.*-64-bit\.exe$" } | Select-Object -First 1
$installerPath = "$env:TEMP\GitSetup.exe"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Git..."
Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS", "/COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Git installed successfully."
