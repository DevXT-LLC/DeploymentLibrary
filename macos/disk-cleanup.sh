#!/bin/bash
# Disk Cleanup (macOS)
# Frees disk space by cleaning caches, logs, and temporary files
set -e
echo "Starting macOS disk cleanup..."

echo ""
echo "--- Disk usage before cleanup ---"
df -h /

# Clean user caches
echo "Cleaning user caches..."
rm -rf ~/Library/Caches/* 2>/dev/null || true

# Clean system caches
echo "Cleaning system caches..."
sudo rm -rf /Library/Caches/* 2>/dev/null || true

# Clean temporary files
echo "Cleaning temporary files..."
sudo rm -rf /tmp/* 2>/dev/null || true
sudo rm -rf /private/var/tmp/* 2>/dev/null || true

# Clean log files
echo "Cleaning old log files..."
sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
sudo find /var/log -type f -name "*.bz2" -delete 2>/dev/null || true
sudo find /private/var/log -type f -mtime +30 -delete 2>/dev/null || true

# Clean Homebrew cache if installed
if command -v brew &>/dev/null; then
    echo "Cleaning Homebrew cache..."
    brew cleanup --prune=all 2>/dev/null || true
fi

# Clean old iOS device backups
if [ -d ~/Library/Application\ Support/MobileSync/Backup ]; then
    BACKUP_SIZE=$(du -sh ~/Library/Application\ Support/MobileSync/Backup 2>/dev/null | cut -f1)
    echo "iOS backups found: ${BACKUP_SIZE:-unknown size} (not deleted — remove manually if not needed)"
fi

# Clean Xcode derived data if present
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    echo "Cleaning Xcode derived data..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
fi

# Remove .DS_Store files system-wide
echo "Removing .DS_Store files..."
sudo find / -name ".DS_Store" -type f -delete 2>/dev/null || true

echo ""
echo "--- Disk usage after cleanup ---"
df -h /
echo ""
echo "macOS disk cleanup complete."
