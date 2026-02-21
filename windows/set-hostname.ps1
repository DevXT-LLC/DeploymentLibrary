# Set Hostname (Windows)
$newHostname = $env:NEW_HOSTNAME
if (-not $newHostname) {
    Write-Host "ERROR: NEW_HOSTNAME environment variable is required."
    exit 1
}
Write-Host "Setting hostname to: $newHostname"
Rename-Computer -NewName $newHostname -Force
Write-Host "Hostname changed to $newHostname. A reboot is required for the change to take effect."
