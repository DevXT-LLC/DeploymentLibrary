# Enable Remote Desktop (Windows)
# Enables RDP and configures firewall rules
Write-Host "Enabling Remote Desktop..."

# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# Enable Network Level Authentication
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1

# Enable firewall rule for RDP
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

# Start RDP service
Set-Service -Name "TermService" -StartupType Automatic
Start-Service -Name "TermService" -ErrorAction SilentlyContinue

Write-Host "Remote Desktop enabled successfully."
Write-Host "Firewall rules updated to allow RDP connections on port 3389."
