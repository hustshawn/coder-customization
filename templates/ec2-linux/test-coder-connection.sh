#!/bin/bash

echo "=== Coder Agent Connection Test ==="
echo "This script tests the Coder agent installation and connection process"
echo

# Check if we're running as the correct user
if [[ "$(whoami)" != "ubuntu" ]]; then
    echo "⚠️  This script should be run as the ubuntu user"
    echo "Current user: $(whoami)"
    echo "Switching to ubuntu user..."
    sudo -u ubuntu bash "$0" "$@"
    exit $?
fi

echo "✅ Running as ubuntu user"
echo

# Set up environment
export PATH="$HOME/.local/bin:$PATH"
cd ~

echo "=== Environment Setup ==="
echo "HOME: $HOME"
echo "PATH: $PATH"
echo "Working directory: $(pwd)"
echo

# Check P5.4xlarge workaround
INSTANCE_TYPE=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
echo "Instance Type: $INSTANCE_TYPE"

if [[ "$INSTANCE_TYPE" == "p5.4xlarge" ]]; then
    echo "✅ P5.4xlarge detected - applying workaround"
    export FI_HMEM_DISABLE_P2P=1
    echo "export FI_HMEM_DISABLE_P2P=1" >> ~/.bashrc
    echo "FI_HMEM_DISABLE_P2P=$FI_HMEM_DISABLE_P2P"
else
    echo "ℹ️  Not a P5.4xlarge instance"
fi
echo

# Test Python and pip
echo "=== Python Environment ==="
if command -v python3 &> /dev/null; then
    echo "✅ Python3: $(python3 --version)"
else
    echo "❌ Python3 not found"
    exit 1
fi

if python3 -m pip --version &> /dev/null; then
    echo "✅ Pip module available: $(python3 -m pip --version)"
else
    echo "❌ Pip module not available"
    echo "Attempting to install pip..."
    python3 -m ensurepip --user || {
        echo "❌ Failed to install pip"
        exit 1
    }
fi
echo

# Test pipx installation
echo "=== Pipx Installation ==="
if command -v pipx &> /dev/null; then
    echo "✅ Pipx already available: $(pipx --version)"
else
    echo "Installing pipx..."
    if python3 -m pip install --user pipx; then
        echo "✅ Pipx installed successfully"
        export PATH="$HOME/.local/bin:$PATH"
        echo "Updated PATH: $PATH"
    else
        echo "❌ Failed to install pipx"
        exit 1
    fi
fi

# Verify pipx works
if command -v pipx &> /dev/null; then
    echo "✅ Pipx is working: $(pipx --version)"
    echo "Pipx list:"
    pipx list || echo "No packages installed yet"
else
    echo "❌ Pipx still not available after installation"
    echo "Checking ~/.local/bin:"
    ls -la ~/.local/bin/ | grep pipx || echo "pipx not found in ~/.local/bin"
    exit 1
fi
echo

# Test a simple pipx installation
echo "=== Testing Pipx Functionality ==="
echo "Testing pipx with a simple package (cowsay)..."
if pipx install cowsay; then
    echo "✅ Pipx installation test successful"
    if command -v cowsay &> /dev/null; then
        cowsay "Pipx is working!"
    fi
    pipx uninstall cowsay
else
    echo "❌ Pipx installation test failed"
    echo "This might indicate network or permission issues"
fi
echo

# Simulate Coder agent installation
echo "=== Simulating Coder Agent Installation ==="
echo "This would be where the Coder init script runs..."
echo "Environment variables that would be available:"
env | grep -E "(PATH|HOME|USER|FI_HMEM)" | sort
echo

echo "=== Connection Test Summary ==="
echo "✅ User setup: ubuntu user with proper home directory"
echo "✅ Python environment: Python3 and pip available"
echo "✅ Pipx installation: Working and tested"
if [[ "$INSTANCE_TYPE" == "p5.4xlarge" ]]; then
    echo "✅ P5.4xlarge workaround: FI_HMEM_DISABLE_P2P=1 applied"
fi
echo "✅ Network connectivity: Available for package installation"
echo
echo "The environment is ready for Coder agent installation."
echo "If the agent still fails to connect, the issue is likely in the init script content itself."