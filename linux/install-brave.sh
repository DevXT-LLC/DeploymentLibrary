#!/bin/bash
# Install Brave Browser (Linux)
# Downloads and installs the latest Brave Browser
set -e
echo "Installing Brave Browser..."
if command -v apt-get &>/dev/null; then
    sudo apt-get install -y curl
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
        sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt-get update
    sudo apt-get install -y brave-browser
elif command -v dnf &>/dev/null; then
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    sudo dnf install -y brave-browser
else
    echo "ERROR: Unsupported package manager. Install manually from https://brave.com/linux/"
    exit 1
fi
echo "Brave Browser installed successfully."
