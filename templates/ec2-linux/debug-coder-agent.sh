#!/bin/bash

echo "=== Coder Agent Debug Script ==="
echo "Timestamp: $(date)"
echo

echo "=== System Information ==="
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo 'Not available')"
echo "Region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo 'Not available')"
echo

echo "=== User Information ==="
echo "Current user: $(whoami)"
echo "User ID: $(id)"
echo "Home directory: $HOME"
echo "Home directory exists: $([ -d "$HOME" ] && echo 'yes' || echo 'no')"
echo "Home directory permissions: $(ls -ld "$HOME" 2>/dev/null || echo 'not accessible')"
echo

echo "=== Python Environment ==="
echo "Python3 location: $(which python3 2>/dev/null || echo 'not found')"
echo "Python3 version: $(python3 --version 2>/dev/null || echo 'not available')"
echo "Pip3 location: $(which pip3 2>/dev/null || echo 'not found')"
echo "Pip3 version: $(pip3 --version 2>/dev/null || echo 'not available')"
echo

echo "=== Pipx Status ==="
echo "Pipx location: $(which pipx 2>/dev/null || echo 'not found')"
if command -v pipx &> /dev/null; then
    echo "Pipx version: $(pipx --version 2>/dev/null || echo 'version not available')"
    echo "Pipx list:"
    pipx list 2>/dev/null || echo "Failed to list pipx packages"
else
    echo "Pipx not found in PATH"
    echo "Checking ~/.local/bin/pipx: $([ -f ~/.local/bin/pipx ] && echo 'exists' || echo 'not found')"
fi
echo

echo "=== PATH Information ==="
echo "PATH: $PATH"
echo "Contents of ~/.local/bin:"
ls -la ~/.local/bin/ 2>/dev/null || echo "~/.local/bin does not exist"
echo

echo "=== Network Connectivity ==="
echo "Internet connectivity:"
if curl -s --connect-timeout 5 https://google.com > /dev/null; then
    echo "✅ Internet connection working"
else
    echo "❌ No internet connection"
fi

echo "Coder API connectivity:"
if curl -s --connect-timeout 5 https://coder.com > /dev/null; then
    echo "✅ Can reach coder.com"
else
    echo "❌ Cannot reach coder.com"
fi
echo

echo "=== Cloud-init Status ==="
echo "Cloud-init status:"
cloud-init status 2>/dev/null || echo "cloud-init status not available"
echo

echo "=== System Logs ==="
echo "Last 20 lines of user-data log:"
tail -20 /var/log/user-data.log 2>/dev/null || echo "User-data log not found"
echo

echo "Last 20 lines of cloud-init output:"
tail -20 /var/log/cloud-init-output.log 2>/dev/null || echo "Cloud-init output log not found"
echo

echo "=== Disk Space ==="
df -h
echo

echo "=== Memory Usage ==="
free -h
echo

echo "=== Running Processes ==="
echo "Coder-related processes:"
ps aux | grep -i coder || echo "No coder processes found"
echo

echo "=== Debug Complete ==="