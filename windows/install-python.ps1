# Install Python (Windows)
# Downloads and installs a specified version of Python
$version = if ($env:PYTHON_VERSION) { $env:PYTHON_VERSION } else { "3.11" }
Write-Host "Downloading Python $version..."
# Get the latest patch version from python.org
$baseUrl = "https://www.python.org/ftp/python/"
$page = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing
$versions = ($page.Links | Where-Object { $_.href -match "^$version\.\d+/" }) | Sort-Object -Property href -Descending
$fullVersion = $versions[0].href.TrimEnd('/')
$installerUrl = "https://www.python.org/ftp/python/$fullVersion/python-$fullVersion-amd64.exe"
$installerPath = "$env:TEMP\python-$fullVersion-amd64.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
Write-Host "Installing Python $fullVersion..."
Start-Process -FilePath $installerPath -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Python $fullVersion installed successfully."
