#!/bin/bash

echo "=== Coder Agent Status Check ==="
echo "Timestamp: $(date)"
echo

echo "1. User-data execution status:"
if [ -f /var/log/user-data.log ]; then
    echo "✅ User-data log exists"
    echo "Last 10 lines:"
    sudo tail -10 /var/log/user-data.log
    echo
    if sudo grep -q "User Data Script Completed" /var/log/user-data.log; then
        echo "✅ User-data completed successfully"
    else
        echo "❌ User-data may not have completed"
    fi
else
    echo "❌ User-data log not found"
fi
echo

echo "2. Cloud-init status:"
cloud-init status
echo

echo "3. Coder agent process:"
if pgrep -f "coder.*agent" > /dev/null; then
    echo "✅ Coder agent is running"
    ps aux | grep -v grep | grep coder
else
    echo "❌ Coder agent not running"
fi
echo

echo "4. Coder agent startup log:"
if [ -f /tmp/coder-agent-startup.log ]; then
    echo "✅ Startup log exists"
    tail -10 /tmp/coder-agent-startup.log
else
    echo "❌ No startup log found"
fi
echo

echo "5. Init script status:"
if [ -f /tmp/coder_init.sh ]; then
    echo "✅ Init script exists"
    echo "Script size: $(wc -l < /tmp/coder_init.sh) lines"
    echo "First 5 lines:"
    head -5 /tmp/coder_init.sh
else
    echo "❌ Init script not found"
fi
echo

echo "6. Coder binary status:"
if [ -f /tmp/coder ]; then
    echo "✅ Coder binary exists in /tmp"
    /tmp/coder --version
elif [ -f ~/coder ]; then
    echo "✅ Coder binary exists in home"
    ~/coder --version
else
    echo "❌ Coder binary not found"
fi
echo

echo "7. Network connectivity:"
if curl -s --connect-timeout 5 https://coder.shawnzh.people.aws.dev > /dev/null; then
    echo "✅ Can reach Coder server"
else
    echo "❌ Cannot reach Coder server"
fi
echo

echo "8. Environment variables:"
env | grep -i coder || echo "No CODER environment variables set"
echo

echo "=== Quick Fix Commands ==="
echo "If agent not running, try:"
echo "cd /tmp && curl -fsSL https://coder.shawnzh.people.aws.dev/bin/coder-linux-amd64 -o coder && chmod +x coder"
echo "export CODER_AGENT_AUTH='aws-instance-identity'"
echo "export CODER_AGENT_URL='https://coder.shawnzh.people.aws.dev/'"
echo "export FI_HMEM_DISABLE_P2P=1"
echo "./coder agent"
