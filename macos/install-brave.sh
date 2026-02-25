#!/bin/bash
# Install Brave Browser (macOS)
# Installs Brave Browser via Homebrew or direct download
set -e
echo "Installing Brave Browser..."

if command -v brew &>/dev/null; then
    brew install --cask brave-browser
else
    echo "Homebrew not found. Downloading Brave directly..."
    DMG_URL="https://laptop-updates.brave.com/latest/osxarm64"
    TEMP_DMG="/tmp/Brave-Browser.dmg"
    curl -fsSL "$DMG_URL" -o "$TEMP_DMG"
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    MOUNT_POINT=$(hdiutil info | grep "Brave" | awk '{print $NF}' | head -1)
    cp -R "${MOUNT_POINT}/Brave Browser.app" /Applications/
    hdiutil detach "$MOUNT_POINT" -quiet
    rm -f "$TEMP_DMG"
fi

echo "Brave Browser installed successfully."
