#!/bin/bash
# Install Google Chrome (macOS)
# Installs Chrome via Homebrew or direct download
set -e
echo "Installing Google Chrome..."

if command -v brew &>/dev/null; then
    brew install --cask google-chrome
else
    echo "Homebrew not found. Downloading Chrome directly..."
    DMG_URL="https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
    TEMP_DMG="/tmp/googlechrome.dmg"
    curl -fsSL "$DMG_URL" -o "$TEMP_DMG"
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    cp -R "/Volumes/Google Chrome/Google Chrome.app" /Applications/
    hdiutil detach "/Volumes/Google Chrome" -quiet
    rm -f "$TEMP_DMG"
fi

echo "Google Chrome installed successfully."
