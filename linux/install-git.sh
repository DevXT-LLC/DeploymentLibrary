#!/bin/bash
# Install Git (Linux)
set -e
echo "Installing Git..."
if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y git
elif command -v dnf &>/dev/null; then
    sudo dnf install -y git
elif command -v yum &>/dev/null; then
    sudo yum install -y git
elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm git
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
git --version
echo "Git installed successfully."
