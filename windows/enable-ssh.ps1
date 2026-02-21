# Enable SSH Server (Windows)
# Installs and enables the OpenSSH server
Write-Host "Enabling SSH Server..."

# Check if OpenSSH Server is already installed
$sshCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Server*" }

if ($sshCapability.State -ne "Installed") {
    Write-Host "Installing OpenSSH Server..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

# Start and enable the SSH service
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# Configure firewall rule
$rule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}

Write-Host "SSH Server enabled successfully on port 22."
