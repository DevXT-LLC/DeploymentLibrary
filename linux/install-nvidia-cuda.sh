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
# Convert dot version (12.8) to dash version (12-8) for package names
CUDA_DASH="${CUDA_VER/./-}"
echo "Installing NVIDIA CUDA Toolkit ${CUDA_VER}..."

# -------------------------------------------------------------------
# Helper: map dpkg arch to NVIDIA repo arch
# NVIDIA uses x86_64/sbsa in their repo URLs, not Debian-style amd64/arm64
# -------------------------------------------------------------------
nvidia_arch() {
    local dpkg_arch
    dpkg_arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    case "$dpkg_arch" in
        amd64|x86_64) echo "x86_64" ;;
        arm64|aarch64) echo "sbsa" ;;
        *) echo "$dpkg_arch" ;;
    esac
}

# -------------------------------------------------------------------
# Helper: check whether the NVIDIA driver is already loaded
# -------------------------------------------------------------------
has_nvidia_driver() {
    command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null
}

# -------------------------------------------------------------------
# apt helper – noninteractive with dpkg options
# -------------------------------------------------------------------
apt_install() {
    sudo DEBIAN_FRONTEND=noninteractive \
        apt-get install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        "$@"
}

if command -v apt-get &>/dev/null; then
    # ---------------------------------------------------------------
    # Ubuntu / Debian
    # ---------------------------------------------------------------
    DISTRO=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')
    RELEASE=$(lsb_release -rs 2>/dev/null | tr -d '.')
    ARCH=$(nvidia_arch)
    REPO_BASE="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}${RELEASE}/${ARCH}"

    # 1. Ensure basic prerequisites are present
    echo "Installing prerequisites..."
    sudo apt-get update
    apt_install \
        build-essential \
        dkms \
        linux-headers-"$(uname -r)" \
        wget \
        gnupg \
        lsb-release \
        pciutils

    # 2. Set up NVIDIA CUDA repository with proper pin priority
    echo "Adding NVIDIA CUDA repository (${DISTRO}${RELEASE}/${ARCH})..."

    # Pin file ensures NVIDIA packages take priority
    wget -q "${REPO_BASE}/cuda-${DISTRO}${RELEASE}.pin" -O /tmp/cuda-pin
    sudo mv /tmp/cuda-pin /etc/apt/preferences.d/cuda-repository-pin-600

    # Install the keyring package for repo authentication
    wget -q "${REPO_BASE}/cuda-keyring_1.1-1_all.deb" -O /tmp/cuda-keyring.deb
    sudo DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/cuda-keyring.deb
    rm -f /tmp/cuda-keyring.deb
    sudo apt-get update

    # 3. Blacklist nouveau so it does not conflict with the NVIDIA driver
    if ! grep -qs "blacklist nouveau" /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null; then
        echo "Blacklisting nouveau driver..."
        sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null <<'NOUVEAU'
blacklist nouveau
options nouveau modeset=0
NOUVEAU
        sudo update-initramfs -u 2>/dev/null || true
    fi

    # 4. Install NVIDIA driver + CUDA toolkit
    #    cuda-drivers installs the actual kernel module; cuda-X-Y installs the toolkit.
    #    The "cuda-X-Y" meta-package alone only pulls userspace libs, NOT the kernel driver.
    if ! has_nvidia_driver; then
        echo "NVIDIA driver not detected – installing kernel driver + CUDA toolkit..."
        apt_install cuda-drivers "cuda-toolkit-${CUDA_DASH}"
    else
        CURRENT_DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1 || true)
        echo "NVIDIA driver ${CURRENT_DRV} already installed – installing CUDA toolkit only..."
        apt_install "cuda-toolkit-${CUDA_DASH}"
    fi

    # 5. Install NVIDIA Container Toolkit (useful for Docker GPU workloads)
    if command -v docker &>/dev/null; then
        echo "Docker detected – installing NVIDIA Container Toolkit..."
        if [ ! -f /usr/share/keyrings/nvidia-container-toolkit.gpg ]; then
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
                sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
        fi
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
        sudo apt-get update
        apt_install nvidia-container-toolkit
        sudo nvidia-ctk runtime configure --runtime=docker 2>/dev/null || true
        sudo systemctl restart docker 2>/dev/null || true
        echo "NVIDIA Container Toolkit installed."
    fi

elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    # ---------------------------------------------------------------
    # RHEL / Fedora / CentOS
    # ---------------------------------------------------------------
    PKG_MGR="dnf"
    command -v dnf &>/dev/null || PKG_MGR="yum"
    ARCH=$(uname -m)

    # 1. Prerequisites
    echo "Installing prerequisites..."
    sudo $PKG_MGR install -y \
        kernel-devel-"$(uname -r)" \
        kernel-headers-"$(uname -r)" \
        gcc \
        gcc-c++ \
        make \
        dkms \
        wget \
        pciutils

    # 2. Add the NVIDIA CUDA repository
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

    # 3. Install driver + toolkit
    if ! has_nvidia_driver; then
        echo "NVIDIA driver not detected – installing kernel driver + CUDA toolkit..."
        sudo $PKG_MGR install -y cuda-drivers "cuda-toolkit-${CUDA_DASH}"
    else
        echo "NVIDIA driver already installed – installing CUDA toolkit only..."
        sudo $PKG_MGR install -y "cuda-toolkit-${CUDA_DASH}"
    fi

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
