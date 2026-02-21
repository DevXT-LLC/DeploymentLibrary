#!/bin/bash
# Disk Cleanup (Linux)
# Frees disk space by cleaning temporary files, caches, and logs
set -e
echo "Starting disk cleanup..."

FREED=0

# Clean package manager cache
if command -v apt-get &>/dev/null; then
    BEFORE=$(df / --output=avail | tail -1)
    sudo apt-get autoremove -y
    sudo apt-get autoclean -y
    sudo apt-get clean
    AFTER=$(df / --output=avail | tail -1)
    DIFF=$((AFTER - BEFORE))
    FREED=$((FREED + DIFF))
    echo "Cleaned: apt cache"
elif command -v dnf &>/dev/null; then
    sudo dnf autoremove -y
    sudo dnf clean all
    echo "Cleaned: dnf cache"
elif command -v yum &>/dev/null; then
    sudo yum autoremove -y
    sudo yum clean all
    echo "Cleaned: yum cache"
fi

# Clean /tmp
sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
echo "Cleaned: /tmp (files older than 7 days)"

# Clean old journal logs (keep last 7 days)
if command -v journalctl &>/dev/null; then
    sudo journalctl --vacuum-time=7d 2>/dev/null || true
    echo "Cleaned: journal logs (older than 7 days)"
fi

# Clean old log files
sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
sudo find /var/log -type f -name "*.old" -delete 2>/dev/null || true
echo "Cleaned: compressed/old log files"

echo "Disk cleanup complete."
df -h /
