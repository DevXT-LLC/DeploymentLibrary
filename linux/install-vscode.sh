#!/bin/bash
# Install Visual Studio Code (Linux)
# Downloads and installs the latest VS Code
set -e
echo "Installing Visual Studio Code..."
if command -v apt-get &>/dev/null; then
    sudo apt-get install -y wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
        sudo tee /etc/apt/sources.list.d/vscode.list
    rm -f /tmp/packages.microsoft.gpg
    sudo apt-get update
    sudo apt-get install -y code
elif command -v dnf &>/dev/null; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | \
        sudo tee /etc/yum.repos.d/vscode.repo
    sudo dnf install -y code
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
echo "Visual Studio Code installed successfully."
