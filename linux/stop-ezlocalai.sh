#!/bin/bash
# Stop ezlocalai server
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-/opt/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Stopping ezlocalai..."

# Try systemd first
if command -v systemctl &>/dev/null && systemctl list-unit-files ezlocalai.service &>/dev/null 2>&1; then
    sudo systemctl stop ezlocalai.service
    echo "ezlocalai stopped via systemd."
    exit 0
fi

# Fall back to CLI
if [ ! -d "${VENV_DIR}" ]; then
    echo "ERROR: ezlocalai venv not found at ${VENV_DIR}"
    exit 1
fi

source "${VENV_DIR}/bin/activate"
cd "${INSTALL_DIR}"
ezlocalai stop
echo "ezlocalai stopped."
