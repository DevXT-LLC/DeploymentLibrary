#!/bin/bash
# Install Homebrew (macOS)
# Installs the Homebrew package manager if not already present
set -e
echo "Checking for Homebrew..."

if command -v brew &>/dev/null; then
    echo "Homebrew is already installed: $(brew --version | head -1)"
    echo "Updating Homebrew..."
    brew update
else
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null

    # Add brew to PATH for Apple Silicon Macs
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        # Add to .zprofile for persistence
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    fi
fi

echo "Homebrew installed successfully: $(brew --version | head -1)"
