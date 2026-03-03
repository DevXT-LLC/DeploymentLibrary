#!/bin/bash
# Restart ezlocalai server
# Uses systemd if available, otherwise falls back to the CLI directly.
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-/opt/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Restarting ezlocalai..."

# Try systemd first
if command -v systemctl &>/dev/null && systemctl list-unit-files ezlocalai.service &>/dev/null 2>&1; then
    sudo systemctl restart ezlocalai.service
    sleep 2
    sudo systemctl status ezlocalai.service --no-pager
    echo "ezlocalai restarted via systemd."
    exit 0
fi

# Fall back to CLI
if [ ! -d "${VENV_DIR}" ]; then
    echo "ERROR: ezlocalai venv not found at ${VENV_DIR}"
    echo "Please run the deploy-ezlocalai script first."
    exit 1
fi

source "${VENV_DIR}/bin/activate"
cd "${INSTALL_DIR}"
ezlocalai restart
echo "ezlocalai restarted."
