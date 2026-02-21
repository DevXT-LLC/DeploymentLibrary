# Run Windows Update
# Checks for and installs available Windows updates
$autoReboot = if ($env:AUTO_REBOOT -eq "true") { $true } else { $false }

Write-Host "Checking for Windows Updates..."

# Install PSWindowsUpdate module if not present
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "Installing PSWindowsUpdate module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}

Import-Module PSWindowsUpdate

# Get available updates
$updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot
if ($updates.Count -eq 0) {
    Write-Host "No updates available."
    exit 0
}

Write-Host "Found $($updates.Count) update(s). Installing..."
if ($autoReboot) {
    Install-WindowsUpdate -AcceptAll -AutoReboot -Verbose
} else {
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -Verbose
}

Write-Host "Windows Update complete."
if (-not $autoReboot) {
    $rebootRequired = Get-WURebootStatus -Silent
    if ($rebootRequired) {
        Write-Host "WARNING: A reboot is required to complete updates."
    }
}
