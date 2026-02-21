#!/bin/bash
# Install Python (Linux)
# Installs a specified version of Python from deadsnakes PPA or source
set -e
VERSION="${PYTHON_VERSION:-3.11}"
echo "Installing Python ${VERSION}..."
if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update
    sudo apt-get install -y "python${VERSION}" "python${VERSION}-venv" "python${VERSION}-dev"
elif command -v dnf &>/dev/null; then
    sudo dnf install -y "python${VERSION}" "python${VERSION}-devel" || {
        echo "Python ${VERSION} not in repos, installing from source..."
        sudo dnf install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel make
        FULL_VERSION=$(curl -s https://www.python.org/ftp/python/ | grep -oP "${VERSION}\.\d+" | sort -V | tail -1)
        cd /tmp
        curl -O "https://www.python.org/ftp/python/${FULL_VERSION}/Python-${FULL_VERSION}.tgz"
        tar xzf "Python-${FULL_VERSION}.tgz"
        cd "Python-${FULL_VERSION}"
        ./configure --enable-optimizations --prefix=/usr/local
        make -j"$(nproc)"
        sudo make altinstall
        cd /tmp && rm -rf "Python-${FULL_VERSION}" "Python-${FULL_VERSION}.tgz"
    }
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
"python${VERSION}" --version
echo "Python ${VERSION} installed successfully."
