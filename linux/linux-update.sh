#!/bin/bash
# Run Linux Updates
# Updates all packages on apt, yum, or dnf based distributions
set -e
AUTO_REBOOT="${AUTO_REBOOT:-false}"

echo "Checking for system updates..."

if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get dist-upgrade -y
    sudo apt-get autoremove -y
elif command -v dnf &>/dev/null; then
    sudo dnf upgrade -y
    sudo dnf autoremove -y
elif command -v yum &>/dev/null; then
    sudo yum update -y
    sudo yum autoremove -y
elif command -v pacman &>/dev/null; then
    sudo pacman -Syu --noconfirm
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi

echo "System updates complete."

# Check if reboot is needed
if [ -f /var/run/reboot-required ]; then
    echo "WARNING: A reboot is required to complete updates."
    if [ "$AUTO_REBOOT" = "true" ]; then
        echo "Auto-reboot enabled. Rebooting in 10 seconds..."
        sleep 10
        sudo reboot
    fi
fi
