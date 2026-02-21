#!/bin/bash
# Install NVIDIA CUDA Toolkit (Linux)
set -e
CUDA_VER="${CUDA_VERSION:-12.6}"
echo "Installing NVIDIA CUDA Toolkit ${CUDA_VER}..."
if command -v apt-get &>/dev/null; then
    # Ubuntu/Debian
    DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    RELEASE=$(lsb_release -rs | tr -d '.')
    ARCH=$(dpkg --print-architecture)
    wget -q "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}${RELEASE}/${ARCH}/cuda-keyring_1.1-1_all.deb" -O /tmp/cuda-keyring.deb
    sudo dpkg -i /tmp/cuda-keyring.deb
    rm -f /tmp/cuda-keyring.deb
    sudo apt-get update
    CUDA_PKG="cuda-toolkit-${CUDA_VER/./-}"
    sudo apt-get install -y "$CUDA_PKG"
elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    # RHEL/Fedora/CentOS
    ARCH=$(uname -m)
    DISTRO="rhel8"
    sudo dnf config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-${DISTRO}.repo" 2>/dev/null || \
    sudo yum-config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-${DISTRO}.repo"
    CUDA_PKG="cuda-toolkit-${CUDA_VER/./-}"
    sudo dnf install -y "$CUDA_PKG" 2>/dev/null || sudo yum install -y "$CUDA_PKG"
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
echo "NVIDIA CUDA Toolkit ${CUDA_VER} installed successfully."
echo "You may need to add /usr/local/cuda/bin to your PATH."
