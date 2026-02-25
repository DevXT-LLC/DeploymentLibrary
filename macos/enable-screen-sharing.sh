#!/bin/bash
# Enable Screen Sharing / VNC (macOS)
# Enables macOS Screen Sharing for remote desktop access
set -e
echo "Enabling Screen Sharing (VNC)..."

# Enable Screen Sharing via kickstart
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
    -activate -configure -access -on \
    -allowAccessFor -allUsers \
    -privs -all \
    -restart -agent

echo "Screen Sharing (VNC) enabled successfully."
echo "Connect via vnc://$(hostname) or Screen Sharing in Finder."
