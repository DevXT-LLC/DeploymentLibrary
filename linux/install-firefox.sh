#!/bin/bash
# Install Firefox (Linux)
# Installs Mozilla Firefox via package manager
set -e
echo "Installing Firefox..."

if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y firefox
elif command -v dnf &>/dev/null; then
    sudo dnf install -y firefox
elif command -v yum &>/dev/null; then
    sudo yum install -y firefox
elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm firefox
else
    echo "ERROR: Unsupported package manager. Install Firefox manually."
    exit 1
fi

echo "Firefox installed successfully."
