#!/bin/bash
# Install Python (macOS)
# Installs Python via Homebrew or the official pkg installer
set -e
PYTHON_VERSION="${PYTHON_VERSION:-3.11}"
echo "Installing Python ${PYTHON_VERSION}..."

if command -v brew &>/dev/null; then
    brew install "python@${PYTHON_VERSION}"
    brew link --overwrite "python@${PYTHON_VERSION}" 2>/dev/null || true
else
    echo "Homebrew not found. Downloading Python installer..."
    # Use the official macOS universal installer
    PKG_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}.0/python-${PYTHON_VERSION}.0-macos11.pkg"
    TEMP_PKG="/tmp/python.pkg"
    curl -fsSL "$PKG_URL" -o "$TEMP_PKG"
    sudo installer -pkg "$TEMP_PKG" -target /
    rm -f "$TEMP_PKG"
fi

echo "Python installed successfully: $(python3 --version)"
