#!/bin/bash
# Reboot Machine
# Gracefully reboots the machine after a configurable delay
DELAY="${REBOOT_DELAY:-5}"
echo "Rebooting machine in ${DELAY} seconds..."
sleep "$DELAY"
sudo reboot
