#!/bin/bash
# Enable FileVault (macOS)
# Enables full-disk encryption via FileVault
set -e
echo "Checking FileVault status..."

STATUS=$(fdesetup status)
echo "$STATUS"

if echo "$STATUS" | grep -q "FileVault is On"; then
    echo "FileVault is already enabled."
    exit 0
fi

echo "Enabling FileVault..."
echo "The recovery key will be stored at /tmp/filevault_recovery_key.plist"
echo "IMPORTANT: Save the recovery key securely and delete the file."

sudo fdesetup enable -outputplist > /tmp/filevault_recovery_key.plist

echo "FileVault has been enabled. A restart is required to begin encryption."
echo "Recovery key saved to /tmp/filevault_recovery_key.plist"
