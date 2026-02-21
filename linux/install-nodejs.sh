#!/bin/bash
# Install Node.js (Linux)
# Uses NodeSource repository for the specified major version
set -e
NODE_VER="${NODE_VERSION:-22}"
echo "Installing Node.js v${NODE_VER}..."
if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VER}.x nodistro main" | \
        sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update
    sudo apt-get install -y nodejs
elif command -v dnf &>/dev/null; then
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VER}.x" | sudo bash -
    sudo dnf install -y nodejs
elif command -v yum &>/dev/null; then
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VER}.x" | sudo bash -
    sudo yum install -y nodejs
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
node --version
npm --version
echo "Node.js v${NODE_VER} installed successfully."
