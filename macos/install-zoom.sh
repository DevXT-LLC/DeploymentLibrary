#!/bin/bash
# Install Zoom (macOS)
# Installs Zoom Client via Homebrew or direct download
set -e
echo "Installing Zoom..."

if command -v brew &>/dev/null; then
    brew install --cask zoom
else
    echo "Homebrew not found. Downloading Zoom directly..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        PKG_URL="https://zoom.us/client/latest/zoomusInstallerFull.pkg?archType=arm64"
    else
        PKG_URL="https://zoom.us/client/latest/zoomusInstallerFull.pkg"
    fi
    TEMP_PKG="/tmp/zoom.pkg"
    curl -fsSL "$PKG_URL" -o "$TEMP_PKG"
    sudo installer -pkg "$TEMP_PKG" -target /
    rm -f "$TEMP_PKG"
fi

echo "Zoom installed successfully."
