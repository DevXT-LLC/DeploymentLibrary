#!/bin/bash
# Restart ezlocalai server (macOS)
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-$HOME/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Restarting ezlocalai..."

if [ ! -d "${VENV_DIR}" ]; then
    echo "ERROR: ezlocalai venv not found at ${VENV_DIR}"
    echo "Please run the deploy-ezlocalai script first."
    exit 1
fi

source "${VENV_DIR}/bin/activate"
cd "${INSTALL_DIR}"
ezlocalai restart
echo "ezlocalai restarted."
