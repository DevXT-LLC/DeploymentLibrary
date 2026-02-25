#!/bin/bash
# Install Node.js (macOS)
# Installs Node.js via Homebrew or the official pkg installer
set -e
NODE_VERSION="${NODE_VERSION:-22}"
echo "Installing Node.js ${NODE_VERSION}..."

if command -v brew &>/dev/null; then
    brew install "node@${NODE_VERSION}"
    brew link --overwrite "node@${NODE_VERSION}" 2>/dev/null || true
else
    echo "Homebrew not found. Downloading Node.js installer..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        PKG_URL="https://nodejs.org/dist/latest-v${NODE_VERSION}.x/node-v${NODE_VERSION}.0-darwin-arm64.tar.gz"
    else
        PKG_URL="https://nodejs.org/dist/latest-v${NODE_VERSION}.x/node-v${NODE_VERSION}.0-darwin-x64.tar.gz"
    fi
    TEMP_FILE="/tmp/nodejs.tar.gz"
    curl -fsSL "$PKG_URL" -o "$TEMP_FILE"
    sudo tar -xzf "$TEMP_FILE" -C /usr/local --strip-components=1
    rm -f "$TEMP_FILE"
fi

echo "Node.js installed successfully: $(node --version 2>/dev/null || echo 'restart shell to verify')"
