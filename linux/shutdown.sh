#!/bin/bash
# Shutdown Machine (Linux/macOS)
DELAY="${SHUTDOWN_DELAY:-5}"
echo "Shutting down machine in ${DELAY} seconds..."
sleep "$DELAY"
sudo shutdown -h now
