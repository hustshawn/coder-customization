#!/bin/bash
set -e

echo "Installing Amazon Q Developer CLI..."

GLIBC_VERSION=$(ldd --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    if awk "BEGIN {exit !($GLIBC_VERSION >= 2.34)}"; then
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux.zip"
    else
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux-musl.zip"
    fi
elif [ "$ARCH" = "aarch64" ]; then
    if awk "BEGIN {exit !($GLIBC_VERSION >= 2.34)}"; then
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-aarch64-linux.zip"
    else
        URL="https://desktop-release.q.us-east-1.amazonaws.com/latest/q-aarch64-linux-musl.zip"
    fi
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

curl --proto '=https' --tlsv1.2 -sSf "$URL" -o "q.zip"
unzip -q q.zip
./q/install.sh
rm -rf q.zip q/

if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

echo "Amazon Q Developer CLI installed successfully!"
