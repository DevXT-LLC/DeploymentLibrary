#!/bin/bash
# macOS Software Update
# Checks for and installs available macOS system updates
set -e
echo "Checking for macOS updates..."

AUTO_REBOOT="${AUTO_REBOOT:-false}"

# List available updates
echo "Available updates:"
softwareupdate --list 2>&1

echo ""
echo "Installing all available updates..."
if [ "$AUTO_REBOOT" = "true" ]; then
    sudo softwareupdate --install --all --restart
else
    sudo softwareupdate --install --all
fi

echo "macOS updates complete."
