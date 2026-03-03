#!/bin/bash
# Stop ezlocalai server (macOS)
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-$HOME/ezlocalai}"
VENV_DIR="${INSTALL_DIR}/.venv"

echo "Stopping ezlocalai..."

if [ ! -d "${VENV_DIR}" ]; then
    echo "ERROR: ezlocalai venv not found at ${VENV_DIR}"
    exit 1
fi

source "${VENV_DIR}/bin/activate"
cd "${INSTALL_DIR}"
ezlocalai stop
echo "ezlocalai stopped."
