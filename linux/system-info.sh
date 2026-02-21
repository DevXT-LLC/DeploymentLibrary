#!/bin/bash
# Collect System Information (Linux/macOS)
echo "=== System Information ==="
echo ""
echo "--- OS ---"
uname -a
cat /etc/os-release 2>/dev/null || sw_vers 2>/dev/null || echo "Unknown OS"
echo ""
echo "--- Hostname ---"
hostname
echo ""
echo "--- CPU ---"
lscpu 2>/dev/null || sysctl -a 2>/dev/null | grep machdep.cpu
echo ""
echo "--- Memory ---"
free -h 2>/dev/null || vm_stat 2>/dev/null
echo ""
echo "--- Disk ---"
df -h
echo ""
echo "--- Network ---"
ip addr show 2>/dev/null || ifconfig
echo ""
echo "--- GPU ---"
lspci 2>/dev/null | grep -i vga || echo "No GPU info available"
nvidia-smi 2>/dev/null || echo "No NVIDIA GPU detected"
echo ""
echo "=== End System Information ==="
