#!/bin/bash
# Create Local User (macOS)
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

# Find next available UniqueID
LAST_ID=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
NEXT_ID=$((LAST_ID + 1))

# Create the user
sudo dscl . -create "/Users/${USERNAME}"
sudo dscl . -create "/Users/${USERNAME}" UserShell /bin/zsh
sudo dscl . -create "/Users/${USERNAME}" RealName "${FULL_NAME}"
sudo dscl . -create "/Users/${USERNAME}" UniqueID "${NEXT_ID}"
sudo dscl . -create "/Users/${USERNAME}" PrimaryGroupID 20
sudo dscl . -create "/Users/${USERNAME}" NFSHomeDirectory "/Users/${USERNAME}"
sudo dscl . -passwd "/Users/${USERNAME}" "${PASSWORD}"

# Create home directory
sudo createhomedir -c -u "${USERNAME}" 2>/dev/null || sudo mkdir -p "/Users/${USERNAME}"

# Add to admin group if requested
if [ "$IS_ADMIN" = "true" ]; then
    sudo dseditgroup -o edit -a "${USERNAME}" -t user admin
    echo "User added to admin group."
fi

echo "Local user '${USERNAME}' created successfully."
