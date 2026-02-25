#!/bin/bash
# Install Git (macOS)
# Installs Git via Xcode Command Line Tools or Homebrew
set -e
echo "Installing Git..."

if command -v git &>/dev/null; then
    echo "Git is already installed: $(git --version)"
fi

if command -v brew &>/dev/null; then
    brew install git
else
    echo "Installing Xcode Command Line Tools (includes Git)..."
    xcode-select --install 2>/dev/null || true
    # Wait for installation to complete
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
fi

echo "Git installed successfully: $(git --version)"
