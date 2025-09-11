#!/bin/bash

echo "=== Coder Agent Connection Test ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo 'unknown')"
echo

echo "=== Environment Check ==="
echo "HOME: $HOME"
echo "PATH: $PATH"
echo "FI_HMEM_DISABLE_P2P: ${FI_HMEM_DISABLE_P2P:-not set}"
echo

echo "=== Python/Pip Check ==="
echo "Python3: $(which python3 2>/dev/null || echo 'not found')"
echo "Python3 version: $(python3 --version 2>/dev/null || echo 'not available')"
echo "Pip3: $(which pip3 2>/dev/null || echo 'not found')"
echo "Pipx: $(which pipx 2>/dev/null || echo 'not found')"
if command -v pipx &>/dev/null; then
    echo "Pipx version: $(pipx --version 2>/dev/null || echo 'error getting version')"
fi
echo

echo "=== Network Connectivity ==="
echo "Testing internet connectivity..."
if curl -s --connect-timeout 10 https://google.com >/dev/null; then
    echo "✅ Internet connection OK"
else
    echo "❌ No internet connection"
fi

echo "Testing Coder connectivity..."
if curl -s --connect-timeout 10 https://coder.com >/dev/null; then
    echo "✅ Can reach coder.com"
else
    echo "❌ Cannot reach coder.com"
fi
echo

echo "=== Process Check ==="
echo "Coder processes:"
ps aux | grep -i coder | grep -v grep || echo "No coder processes found"
echo

echo "=== Log Files ==="
echo "User data log (last 10 lines):"
sudo tail -10 /var/log/user-data.log 2>/dev/null || echo "User data log not found"
echo

echo "Cloud-init output (last 10 lines):"
sudo tail -10 /var/log/cloud-init-output.log 2>/dev/null || echo "Cloud-init log not found"
echo

echo "Coder agent startup log:"
cat /tmp/coder-agent-startup.log 2>/dev/null || echo "Agent startup log not found"
echo

echo "=== System Status ==="
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo

echo "=== Test Complete ==="