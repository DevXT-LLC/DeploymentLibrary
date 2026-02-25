#!/bin/bash
# Create Local User (Linux)
# Creates a new local user account
set -e
USERNAME="${NEW_USERNAME}"
FULL_NAME="${NEW_FULLNAME:-$USERNAME}"
PASSWORD="${NEW_PASSWORD}"
IS_ADMIN="${MAKE_ADMIN:-false}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "ERROR: NEW_USERNAME and NEW_PASSWORD environment variables are required."
    exit 1
fi

echo "Creating local user: ${USERNAME}..."

# Create user with home directory
sudo useradd -m -c "${FULL_NAME}" -s /bin/bash "${USERNAME}"

# Set password
echo "${USERNAME}:${PASSWORD}" | sudo chpasswd

# Add to sudo group if admin
if [ "$IS_ADMIN" = "true" ]; then
    if getent group sudo &>/dev/null; then
        sudo usermod -aG sudo "${USERNAME}"
    elif getent group wheel &>/dev/null; then
        sudo usermod -aG wheel "${USERNAME}"
    fi
    echo "User added to admin/sudo group."
fi

echo "Local user '${USERNAME}' created successfully."
