#!/bin/bash
# Set Timezone (Linux)
# Changes the system timezone
TIMEZONE="${TIMEZONE}"
if [ -z "$TIMEZONE" ]; then
    echo "ERROR: TIMEZONE environment variable is required (e.g. America/New_York)."
    echo "Available timezones: timedatectl list-timezones"
    exit 1
fi

echo "Setting timezone to: ${TIMEZONE}"
sudo timedatectl set-timezone "$TIMEZONE"
echo "Timezone set to: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
