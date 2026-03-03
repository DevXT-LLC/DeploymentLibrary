#!/bin/bash
# Check ezlocalai server status
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-/opt/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Checking ezlocalai status..."

# Try systemd first
if command -v systemctl &>/dev/null && systemctl list-unit-files ezlocalai.service &>/dev/null 2>&1; then
    sudo systemctl status ezlocalai.service --no-pager || true
    echo ""
fi

# Also check via CLI
if [ -d "${VENV_DIR}" ]; then
    source "${VENV_DIR}/bin/activate"
    cd "${INSTALL_DIR}"
    ezlocalai status
else
    echo "ezlocalai is not installed at ${INSTALL_DIR}"
    exit 1
fi
