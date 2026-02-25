#!/bin/bash
# Install Rust (macOS/Linux)
# Installs Rust toolchain via rustup
set -e
echo "Installing Rust..."

if command -v rustup &>/dev/null; then
    echo "Rust is already installed. Updating..."
    rustup update
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

echo "Rust installed successfully: $(rustc --version)"
echo "Cargo: $(cargo --version)"
