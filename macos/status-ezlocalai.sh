#!/bin/bash
# Check ezlocalai server status (macOS)
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-$HOME/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Checking ezlocalai status..."

if [ -d "${VENV_DIR}" ]; then
    source "${VENV_DIR}/bin/activate"
    cd "${INSTALL_DIR}"
    ezlocalai status
else
    echo "ezlocalai is not installed at ${INSTALL_DIR}"
    exit 1
fi
