#!/bin/bash
# Flush DNS Cache (Linux/macOS)
echo "Flushing DNS cache..."
if [[ "$(uname)" == "Darwin" ]]; then
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
elif command -v systemd-resolve &>/dev/null; then
    sudo systemd-resolve --flush-caches
elif command -v resolvectl &>/dev/null; then
    sudo resolvectl flush-caches
elif [ -f /etc/init.d/nscd ]; then
    sudo /etc/init.d/nscd restart
else
    echo "No known DNS cache service found. Restarting networking..."
    sudo systemctl restart systemd-resolved 2>/dev/null || \
    sudo systemctl restart NetworkManager 2>/dev/null || \
    echo "Could not flush DNS cache automatically."
fi
echo "DNS cache flushed successfully."
