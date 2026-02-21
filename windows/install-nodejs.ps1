# Install Node.js (Windows)
# Downloads and installs Node.js LTS
$nodeVersion = if ($env:NODE_VERSION) { $env:NODE_VERSION } else { "22" }
Write-Host "Downloading Node.js v$nodeVersion LTS..."
$installerUrl = "https://nodejs.org/dist/latest-v${nodeVersion}.x/"
$page = Invoke-WebRequest -Uri $installerUrl -UseBasicParsing
$msiFile = ($page.Links | Where-Object { $_.href -match "node-v.*-x64\.msi$" } | Select-Object -First 1).href
$downloadUrl = "${installerUrl}${msiFile}"
$installerPath = "$env:TEMP\$msiFile"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Node.js..."
Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/qn", "/norestart" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Node.js installed successfully."
