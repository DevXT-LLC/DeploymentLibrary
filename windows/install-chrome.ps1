# Install Google Chrome (Windows)
Write-Host "Downloading Google Chrome..."
$installerUrl = "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
$installerPath = "$env:TEMP\ChromeSetup.msi"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Google Chrome..."
Start-Process msiexec.exe -ArgumentList "/i", "`"$installerPath`"", "/qn", "/norestart" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Google Chrome installed successfully."
