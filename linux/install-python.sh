#!/bin/bash
# Install Python (Linux)
# Installs a specified version of Python from deadsnakes PPA (if available) or builds from source
set -e
VERSION="${PYTHON_VERSION:-3.11}"
echo "Installing Python ${VERSION}..."

install_from_source() {
    local ver="$1"
    echo "Installing Python ${ver} from source..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y build-essential gcc libssl-dev libbz2-dev \
            libffi-dev zlib1g-dev libreadline-dev libsqlite3-dev liblzma-dev \
            libncurses5-dev libncursesw5-dev make wget
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel make wget
    elif command -v yum &>/dev/null; then
        sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel make wget
    fi
    FULL_VERSION=$(curl -s https://www.python.org/ftp/python/ | grep -oP "${ver}\.\d+" | sort -V | tail -1)
    if [ -z "$FULL_VERSION" ]; then
        echo "ERROR: Could not find a Python ${ver}.x release."
        exit 1
    fi
    echo "Building Python ${FULL_VERSION}..."
    cd /tmp
    curl -O "https://www.python.org/ftp/python/${FULL_VERSION}/Python-${FULL_VERSION}.tgz"
    tar xzf "Python-${FULL_VERSION}.tgz"
    cd "Python-${FULL_VERSION}"
    ./configure --enable-optimizations --prefix=/usr/local
    make -j"$(nproc)"
    sudo make altinstall
    cd /tmp && rm -rf "Python-${FULL_VERSION}" "Python-${FULL_VERSION}.tgz"
}

if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    # Try deadsnakes PPA first (may not have packages for all arch/distro combos)
    sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
    sudo apt-get update
    if apt-cache show "python${VERSION}" &>/dev/null; then
        sudo apt-get install -y "python${VERSION}" "python${VERSION}-venv" "python${VERSION}-dev" || {
            echo "apt install failed, falling back to source build..."
            install_from_source "$VERSION"
        }
    else
        echo "python${VERSION} not available in repos for this platform, building from source..."
        install_from_source "$VERSION"
    fi
elif command -v dnf &>/dev/null; then
    sudo dnf install -y "python${VERSION}" "python${VERSION}-devel" || {
        install_from_source "$VERSION"
    }
elif command -v yum &>/dev/null; then
    sudo yum install -y "python${VERSION}" "python${VERSION}-devel" || {
        install_from_source "$VERSION"
    }
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
"python${VERSION}" --version
echo "Python ${VERSION} installed successfully."
