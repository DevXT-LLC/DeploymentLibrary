#!/bin/bash
# Set Hostname (macOS)
# Changes the machine's hostname, local hostname, and computer name
NEW_NAME="${NEW_HOSTNAME}"
if [ -z "$NEW_NAME" ]; then
    echo "ERROR: NEW_HOSTNAME environment variable is required."
    exit 1
fi

echo "Setting hostname to: ${NEW_NAME}"
sudo scutil --set ComputerName "$NEW_NAME"
sudo scutil --set LocalHostName "$NEW_NAME"
sudo scutil --set HostName "$NEW_NAME"

echo "Hostname changed to ${NEW_NAME}."
echo "  ComputerName: $(scutil --get ComputerName)"
echo "  LocalHostName: $(scutil --get LocalHostName)"
echo "  HostName: $(scutil --get HostName)"
