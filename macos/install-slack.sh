#!/bin/bash
# Install Slack (macOS)
# Installs Slack via Homebrew or direct download
set -e
echo "Installing Slack..."

if command -v brew &>/dev/null; then
    brew install --cask slack
else
    echo "Homebrew not found. Downloading Slack directly..."
    DMG_URL="https://slack.com/ssb/download-osx-universal"
    TEMP_DMG="/tmp/Slack.dmg"
    curl -fsSL -L "$DMG_URL" -o "$TEMP_DMG"
    hdiutil attach "$TEMP_DMG" -nobrowse -quiet
    cp -R "/Volumes/Slack/Slack.app" /Applications/ 2>/dev/null || \
    cp -R /Volumes/Slack*/Slack.app /Applications/
    hdiutil detach /Volumes/Slack* -quiet 2>/dev/null || true
    rm -f "$TEMP_DMG"
fi

echo "Slack installed successfully."
