#!/bin/bash
# Install PowerShell (Linux)
set -e
echo "Installing PowerShell..."
if command -v apt-get &>/dev/null; then
    # Ubuntu/Debian
    sudo apt-get update
    sudo apt-get install -y wget apt-transport-https software-properties-common
    DISTRO_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    DISTRO_VERSION=$(lsb_release -rs)
    wget -q "https://packages.microsoft.com/config/${DISTRO_ID}/${DISTRO_VERSION}/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y powershell
elif command -v dnf &>/dev/null; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    curl -sSL "https://packages.microsoft.com/config/rhel/8/prod.repo" | sudo tee /etc/yum.repos.d/microsoft.repo
    sudo dnf install -y powershell
elif command -v yum &>/dev/null; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    curl -sSL "https://packages.microsoft.com/config/rhel/7/prod.repo" | sudo tee /etc/yum.repos.d/microsoft.repo
    sudo yum install -y powershell
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
pwsh --version
echo "PowerShell installed successfully."
