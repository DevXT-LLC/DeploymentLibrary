#!/bin/bash
# Install NVIDIA CUDA Toolkit (Linux)
# Handles full installation including prerequisites, NVIDIA drivers, and CUDA toolkit.
# Supports machines with no existing NVIDIA drivers installed.
set -e

# -------------------------------------------------------------------
# Ensure fully non-interactive operation (no TTY required)
# -------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

CUDA_VER="${CUDA_VERSION:-12.8}"
echo "Installing NVIDIA CUDA Toolkit ${CUDA_VER}..."

# -------------------------------------------------------------------
# Helper: check whether the NVIDIA driver is already loaded
# -------------------------------------------------------------------
has_nvidia_driver() {
    nvidia-smi &>/dev/null
}

if command -v apt-get &>/dev/null; then
    # ---------------------------------------------------------------
    # Ubuntu / Debian
    # ---------------------------------------------------------------

    # 1. Ensure basic prerequisites are present
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        build-essential \
        dkms \
        linux-headers-"$(uname -r)" \
        wget \
        gnupg \
        lsb-release

    # 2. Determine distro identifiers for the CUDA repo
    DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    RELEASE=$(lsb_release -rs | tr -d '.')
    ARCH=$(dpkg --print-architecture)

    # 3. Add the NVIDIA CUDA repository (idempotent – safe to re-run)
    KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}${RELEASE}/${ARCH}/cuda-keyring_1.1-1_all.deb"
    echo "Adding NVIDIA CUDA repository (${DISTRO}${RELEASE}/${ARCH})..."
    wget -q "$KEYRING_URL" -O /tmp/cuda-keyring.deb
    sudo DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/cuda-keyring.deb
    rm -f /tmp/cuda-keyring.deb
    sudo apt-get update -qq

    # 4. Install NVIDIA driver if not already present
    if ! has_nvidia_driver; then
        echo "NVIDIA driver not detected – installing driver..."
        # cuda-drivers pulls the recommended driver version for the installed GPU
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" cuda-drivers
        echo "NVIDIA driver installed."
    else
        echo "NVIDIA driver already installed ($(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1))."
    fi

    # 5. Install the CUDA toolkit
    CUDA_PKG="cuda-toolkit-${CUDA_VER/./-}"
    echo "Installing ${CUDA_PKG}..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "$CUDA_PKG"

elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    # ---------------------------------------------------------------
    # RHEL / Fedora / CentOS
    # ---------------------------------------------------------------
    PKG_MGR="dnf"
    command -v dnf &>/dev/null || PKG_MGR="yum"

    # 1. Prerequisites
    sudo $PKG_MGR install -y \
        kernel-devel-"$(uname -r)" \
        kernel-headers-"$(uname -r)" \
        gcc \
        gcc-c++ \
        make \
        dkms \
        wget

    # 2. Add the NVIDIA CUDA repository
    ARCH=$(uname -m)
    # Detect RHEL major version (fallback to 8)
    if [ -f /etc/os-release ]; then
        RHEL_VER=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
    else
        RHEL_VER=8
    fi
    DISTRO="rhel${RHEL_VER}"
    REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-${DISTRO}.repo"

    echo "Adding NVIDIA CUDA repository (${DISTRO}/${ARCH})..."
    if [ "$PKG_MGR" = "dnf" ]; then
        sudo dnf config-manager --add-repo "$REPO_URL"
    else
        sudo yum-config-manager --add-repo "$REPO_URL"
    fi

    # 3. Install NVIDIA driver if not already present
    if ! has_nvidia_driver; then
        echo "NVIDIA driver not detected – installing driver..."
        sudo $PKG_MGR install -y cuda-drivers
        echo "NVIDIA driver installed."
    else
        echo "NVIDIA driver already installed ($(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1))."
    fi

    # 4. Install the CUDA toolkit
    CUDA_PKG="cuda-toolkit-${CUDA_VER/./-}"
    echo "Installing ${CUDA_PKG}..."
    sudo $PKG_MGR install -y "$CUDA_PKG"

else
    echo "ERROR: Unsupported package manager. This script supports apt (Ubuntu/Debian) and dnf/yum (RHEL/Fedora/CentOS)."
    exit 1
fi

# -------------------------------------------------------------------
# Post-install: set up environment variables
# -------------------------------------------------------------------
CUDA_HOME="/usr/local/cuda"
if [ -d "$CUDA_HOME" ]; then
    PROFILE_SCRIPT="/etc/profile.d/cuda.sh"
    if [ ! -f "$PROFILE_SCRIPT" ]; then
        echo "Configuring CUDA environment variables in ${PROFILE_SCRIPT}..."
        sudo tee "$PROFILE_SCRIPT" > /dev/null <<'ENVEOF'
export PATH=/usr/local/cuda/bin${PATH:+:$PATH}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ENVEOF
        sudo chmod 644 "$PROFILE_SCRIPT"
    fi
fi

echo ""
echo "NVIDIA CUDA Toolkit ${CUDA_VER} installed successfully."
if has_nvidia_driver; then
    echo "GPU detected:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || true
fi
echo ""
echo "NOTE: A reboot may be required for the NVIDIA driver to fully initialize."
echo "CUDA environment variables will be loaded on next login (via /etc/profile.d/cuda.sh)."
