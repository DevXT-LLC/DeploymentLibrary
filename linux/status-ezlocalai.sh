#!/bin/bash
# Check ezlocalai server status
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-/opt/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Checking ezlocalai status..."

if [ ! -d "${VENV_DIR}" ]; then
    echo "ezlocalai is not installed at ${INSTALL_DIR}"
    exit 1
fi

source "${VENV_DIR}/bin/activate"
cd "${INSTALL_DIR}"
ezlocalai status
