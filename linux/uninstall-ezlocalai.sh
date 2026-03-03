#!/bin/bash
# Uninstall ezlocalai
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-/opt/ezlocalai}"

echo "============================================="
echo "  Uninstalling ezlocalai"
echo "============================================="

# Stop and disable systemd service
if command -v systemctl &>/dev/null; then
    if systemctl list-unit-files ezlocalai.service &>/dev/null 2>&1; then
        echo "Stopping and disabling systemd service..."
        sudo systemctl stop ezlocalai.service 2>/dev/null || true
        sudo systemctl disable ezlocalai.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/ezlocalai.service
        sudo systemctl daemon-reload
    fi
fi

# Stop any running containers
if command -v docker &>/dev/null; then
    docker stop ezlocalai 2>/dev/null || true
    docker rm ezlocalai 2>/dev/null || true
fi

# Remove installation directory
if [ -d "${INSTALL_DIR}" ]; then
    echo "Removing installation directory: ${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}"
fi

echo ""
echo "ezlocalai has been uninstalled."
echo "Note: Docker images (if any) were not removed. Run 'docker rmi ezlocalai:cuda' to remove them."
