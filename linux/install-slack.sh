#!/bin/bash
# Install Slack (Linux)
# Installs Slack via snap or deb package
set -e
echo "Installing Slack..."

if command -v snap &>/dev/null; then
    sudo snap install slack --classic
elif command -v apt-get &>/dev/null; then
    TEMP_DEB="/tmp/slack.deb"
    curl -fsSL "https://downloads.slack-edge.com/desktop-releases/linux/x64/4.41.105/slack-desktop-4.41.105-amd64.deb" -o "$TEMP_DEB"
    sudo dpkg -i "$TEMP_DEB" || sudo apt-get install -f -y
    rm -f "$TEMP_DEB"
elif command -v dnf &>/dev/null; then
    sudo dnf install -y https://downloads.slack-edge.com/desktop-releases/linux/x64/4.41.105/slack-4.41.105-0.1.el8.x86_64.rpm
else
    echo "ERROR: Unsupported package manager. Install Slack manually from https://slack.com/downloads/linux"
    exit 1
fi

echo "Slack installed successfully."
