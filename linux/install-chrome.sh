#!/bin/bash
# Install Google Chrome (Linux)
set -e
echo "Installing Google Chrome..."
if command -v apt-get &>/dev/null; then
    wget -q -O /tmp/google-chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    sudo apt-get install -y /tmp/google-chrome.deb
    rm -f /tmp/google-chrome.deb
elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    wget -q -O /tmp/google-chrome.rpm "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
    sudo dnf install -y /tmp/google-chrome.rpm 2>/dev/null || sudo yum install -y /tmp/google-chrome.rpm
    rm -f /tmp/google-chrome.rpm
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
google-chrome --version
echo "Google Chrome installed successfully."
