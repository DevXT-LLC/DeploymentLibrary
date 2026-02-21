# Install 7-Zip (Windows)
Write-Host "Downloading 7-Zip..."
$apiUrl = "https://www.7-zip.org/download.html"
$page = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing
$link = ($page.Links | Where-Object { $_.href -match "7z.*-x64\.exe$" } | Select-Object -First 1).href
if ($link -notmatch "^http") { $link = "https://www.7-zip.org/$link" }
$installerPath = "$env:TEMP\7zSetup.exe"
Invoke-WebRequest -Uri $link -OutFile $installerPath -UseBasicParsing
Write-Host "Installing 7-Zip..."
Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "7-Zip installed successfully."
