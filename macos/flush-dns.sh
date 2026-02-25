#!/bin/bash
set -e

# Flush DNS Cache on macOS
# Uses dscacheutil and mDNSResponder (macOS-specific)

echo "Flushing DNS cache on macOS..."

# Flush the directory service cache
dscacheutil -flushcache

# Restart the mDNSResponder service to clear DNS cache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "DNS cache flushed successfully."
