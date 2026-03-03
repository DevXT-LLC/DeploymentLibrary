#!/bin/bash
# Uninstall ezlocalai (macOS)
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-$HOME/ezlocalai}"

echo "============================================="
echo "  Uninstalling ezlocalai"
echo "============================================="

# Unload launchd agent
PLIST_FILE="$HOME/Library/LaunchAgents/com.devxt.ezlocalai.plist"
if [ -f "${PLIST_FILE}" ]; then
    echo "Unloading LaunchAgent..."
    launchctl unload "${PLIST_FILE}" 2>/dev/null || true
    rm -f "${PLIST_FILE}"
fi

# Stop any running containers
if command -v docker &>/dev/null; then
    docker stop ezlocalai 2>/dev/null || true
    docker rm ezlocalai 2>/dev/null || true
fi

# Stop via CLI if possible
VENV_DIR="${INSTALL_DIR}/.venv"
if [ -d "${VENV_DIR}" ]; then
    source "${VENV_DIR}/bin/activate" 2>/dev/null || true
    cd "${INSTALL_DIR}" 2>/dev/null || true
    ezlocalai stop 2>/dev/null || true
fi

# Remove installation directory
if [ -d "${INSTALL_DIR}" ]; then
    echo "Removing installation directory: ${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}"
fi

echo ""
echo "ezlocalai has been uninstalled."
echo "Note: Docker images (if any) were not removed. Run 'docker rmi ezlocalai:cuda' to remove them."
