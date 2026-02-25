#!/bin/bash
# Install Firefox (macOS)
# Installs Mozilla Firefox via Homebrew or direct download
set -e
echo "Installing Firefox..."

if command -v brew &>/dev/null; then
    brew install --cask firefox
else
    echo "Homebrew not found. Downloading Firefox directly..."
    DMG_URL="https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US"
    TEMP_DMG="/tmp/Firefox.dmg"
    curl -fsSL "$DMG_URL" -o "$TEMP_DMG"
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    cp -R "/Volumes/Firefox/Firefox.app" /Applications/
    hdiutil detach "/Volumes/Firefox" -quiet
    rm -f "$TEMP_DMG"
fi

echo "Firefox installed successfully."
