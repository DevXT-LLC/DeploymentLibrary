#!/bin/bash
# Install Docker Engine (Linux)
set -e
echo "Installing Docker Engine..."
if command -v apt-get &>/dev/null; then
    # Remove old versions and stale Docker apt sources from prior attempts
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /etc/apt/keyrings/docker.gpg

    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    # Detect distro: Ubuntu or Debian (including Raspberry Pi OS)
    . /etc/os-release
    DISTRO_ID="${ID}"
    CODENAME="${VERSION_CODENAME}"

    # Raspberry Pi OS and other Debian derivatives should use "debian"
    if [ "$DISTRO_ID" != "ubuntu" ]; then
        DISTRO_ID="debian"
        # If the codename doesn't have a Docker release (e.g. trixie), fall back to bookworm
        case "$CODENAME" in
            bookworm|bullseye|buster) ;;
            *) CODENAME="bookworm" ;;
        esac
    fi

    echo "Using Docker repo: download.docker.com/linux/${DISTRO_ID} ${CODENAME}"

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} ${CODENAME} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif command -v dnf &>/dev/null; then
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif command -v yum &>/dev/null; then
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "ERROR: Unsupported package manager."
    exit 1
fi
sudo systemctl start docker
sudo systemctl enable docker
# Add current user to docker group
sudo usermod -aG docker "$USER" 2>/dev/null || true
docker --version
echo "Docker installed successfully."
