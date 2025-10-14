#!/bin/bash
set -e

echo "Installing Amazon Q Developer CLI in workspace..."

# Check glibc version
echo "Checking glibc version..."
GLIBC_VERSION=$(ldd --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
echo "Detected glibc version: $GLIBC_VERSION"

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# Determine download URL based on architecture and glibc version
if [ "$ARCH" = "x86_64" ]; then
    if awk "BEGIN {exit !($GLIBC_VERSION >= 2.34)}"; then
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux.zip"
        echo "Using standard x86_64 version (glibc >= 2.34)"
    else
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux-musl.zip"
        echo "Using musl x86_64 version (glibc < 2.34)"
    fi
elif [ "$ARCH" = "aarch64" ]; then
    if awk "BEGIN {exit !($GLIBC_VERSION >= 2.34)}"; then
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-aarch64-linux.zip"
        echo "Using standard aarch64 version (glibc >= 2.34)"
    else
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-aarch64-linux-musl.zip"
        echo "Using musl aarch64 version (glibc < 2.34)"
    fi
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Download Amazon Q CLI
echo "Downloading Amazon Q CLI..."
curl --proto '=https' --tlsv1.2 -sSf "$URL" -o "q.zip"

# Extract and install
echo "Extracting and installing..."
unzip q.zip
./q/install.sh

# Clean up
rm -rf q.zip q/

# Add to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "Added ~/.local/bin to PATH in ~/.bashrc"
fi

echo ""
echo "Amazon Q Developer CLI installed successfully!"
echo "Run 'source ~/.bashrc' or start a new shell session, then run 'q --help' to get started."
echo "You can also run 'q doctor' to verify the installation."
