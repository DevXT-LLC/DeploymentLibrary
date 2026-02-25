#!/bin/bash
# Set Timezone (macOS)
# Changes the system timezone
TIMEZONE="${TIMEZONE}"
if [ -z "$TIMEZONE" ]; then
    echo "ERROR: TIMEZONE environment variable is required (e.g. America/New_York)."
    echo "Available timezones: sudo systemsetup -listtimezones"
    exit 1
fi

echo "Setting timezone to: ${TIMEZONE}"
sudo systemsetup -settimezone "$TIMEZONE"
echo "Timezone set to: $(sudo systemsetup -gettimezone | awk -F': ' '{print $2}')"
