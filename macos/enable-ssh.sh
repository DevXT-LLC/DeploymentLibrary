#!/bin/bash
# Enable SSH Server (macOS)
# Enables Remote Login (SSH) via systemsetup
set -e
echo "Enabling SSH Server on macOS..."

# Enable Remote Login (SSH)
sudo systemsetup -setremotelogin on

# Verify
STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | awk '{print $NF}')
echo "Remote Login (SSH) is now: ${STATUS}"

# Ensure firewall allows SSH if firewall is enabled
FIREWALL_STATE=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | awk '{print $NF}')
if [ "$FIREWALL_STATE" = "enabled." ] || [ "$FIREWALL_STATE" = "1" ]; then
    echo "Firewall is enabled. Adding SSH exception..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/sbin/sshd
fi

echo "SSH Server enabled successfully on port 22."
