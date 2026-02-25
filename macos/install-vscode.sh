#!/bin/bash
# Install Visual Studio Code (macOS)
# Installs VS Code via Homebrew or direct download
set -e
echo "Installing Visual Studio Code..."

if command -v brew &>/dev/null; then
    brew install --cask visual-studio-code
else
    echo "Homebrew not found. Downloading VS Code directly..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        ZIP_URL="https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64"
    else
        ZIP_URL="https://code.visualstudio.com/sha/download?build=stable&os=darwin"
    fi
    TEMP_ZIP="/tmp/VSCode.zip"
    curl -fsSL "$ZIP_URL" -o "$TEMP_ZIP"
    unzip -q -o "$TEMP_ZIP" -d /Applications/
    rm -f "$TEMP_ZIP"
fi

echo "Visual Studio Code installed successfully."
