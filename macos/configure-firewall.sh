#!/bin/bash
# Configure macOS Firewall
# Enables and configures the macOS Application Firewall
set -e
echo "Configuring macOS Firewall..."

# Enable the firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Enable stealth mode (don't respond to pings/probes)
STEALTH="${ENABLE_STEALTH:-true}"
if [ "$STEALTH" = "true" ]; then
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    echo "Stealth mode: enabled"
fi

# Block all incoming connections except essential services
BLOCK_ALL="${BLOCK_ALL_INCOMING:-false}"
if [ "$BLOCK_ALL" = "true" ]; then
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on
    echo "Block all incoming: enabled"
fi

# Show current status
echo ""
echo "--- Firewall Status ---"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall
echo ""
echo "macOS Firewall configured successfully."
