#!/bin/bash
# Enable SSH Server (Linux)
# Installs and enables the OpenSSH server
set -e
echo "Enabling SSH Server..."

if command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y openssh-server
elif command -v dnf &>/dev/null; then
    sudo dnf install -y openssh-server
elif command -v yum &>/dev/null; then
    sudo yum install -y openssh-server
elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm openssh
fi

sudo systemctl start sshd
sudo systemctl enable sshd

# Configure firewall if ufw is available
if command -v ufw &>/dev/null; then
    sudo ufw allow ssh
    echo "UFW firewall rule added for SSH."
elif command -v firewall-cmd &>/dev/null; then
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --reload
    echo "Firewalld rule added for SSH."
fi

echo "SSH Server enabled successfully on port 22."
