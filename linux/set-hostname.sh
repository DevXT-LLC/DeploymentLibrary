#!/bin/bash
# Set Hostname (Linux)
NEW_NAME="${NEW_HOSTNAME}"
if [ -z "$NEW_NAME" ]; then
    echo "ERROR: NEW_HOSTNAME environment variable is required."
    exit 1
fi
echo "Setting hostname to: ${NEW_NAME}"
sudo hostnamectl set-hostname "$NEW_NAME"
# Update /etc/hosts
sudo sed -i "s/127\.0\.1\.1.*/127.0.1.1\t${NEW_NAME}/" /etc/hosts
echo "Hostname changed to ${NEW_NAME}."
hostname
