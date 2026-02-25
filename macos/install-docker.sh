#!/bin/bash
# Install Docker Desktop (macOS)
# Installs Docker Desktop via Homebrew or direct download
set -e
echo "Installing Docker Desktop..."

if command -v brew &>/dev/null; then
    brew install --cask docker
else
    echo "Homebrew not found. Downloading Docker Desktop directly..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        DMG_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    else
        DMG_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi
    TEMP_DMG="/tmp/Docker.dmg"
    curl -fsSL "$DMG_URL" -o "$TEMP_DMG"
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    cp -R "/Volumes/Docker/Docker.app" /Applications/
    hdiutil detach "/Volumes/Docker" -quiet
    rm -f "$TEMP_DMG"
fi

echo "Docker Desktop installed. Launch it from Applications to complete setup."
