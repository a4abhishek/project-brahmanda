#!/bin/bash
#
# initialize-macos.sh - Initialize development environment for Project Brahmanda on macOS
#
# This script installs the necessary tools for Project Brahmanda on macOS using Homebrew.

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to print messages
info() {
    echo "INFO: $1"
}

info "Starting tool installation for macOS..."

# 1. Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "ERROR: Homebrew is not installed. Please install it first from https://brew.sh/"
    exit 1
fi

# 2. Update Homebrew
info "Updating Homebrew..."
brew update

# 3. Install tools
info "Installing Terraform, Ansible, and 1Password CLI..."
# Brew install is idempotent; it will only install if the formula is not already installed.
brew install terraform ansible 1password-cli

# 4. Install Proxmox Auto-Install Assistant
# Note: Not available via Homebrew, must download from Proxmox Git
info "Installing Proxmox Auto-Install Assistant..."
PROXMOX_ASSISTANT_PATH="/usr/local/bin/proxmox-auto-install-assistant"

if [ -f "$PROXMOX_ASSISTANT_PATH" ] && [ -x "$PROXMOX_ASSISTANT_PATH" ]; then
    info "Proxmox Auto-Install Assistant already installed at $PROXMOX_ASSISTANT_PATH, skipping..."
else
    info "Downloading Proxmox Auto-Install Assistant from Proxmox Git..."
    PROXMOX_ASSISTANT_URL="https://git.proxmox.com/?p=pve-installer.git;a=blob_plain;f=proxmox-auto-install-assistant;hb=HEAD"
    
    if sudo curl --retry 3 --max-time 30 -fsSL -o "$PROXMOX_ASSISTANT_PATH" "$PROXMOX_ASSISTANT_URL" 2>/dev/null; then
        sudo chmod +x "$PROXMOX_ASSISTANT_PATH"
        info "✅ Proxmox Auto-Install Assistant installed to $PROXMOX_ASSISTANT_PATH"
    else
        echo "ERROR: Failed to download Proxmox Auto-Install Assistant"
        echo "This tool is optional. You can continue without it."
        echo "To install manually: sudo curl -fsSL -o $PROXMOX_ASSISTANT_PATH 'https://git.proxmox.com/?p=pve-installer.git;a=blob_plain;f=proxmox-auto-install-assistant;hb=HEAD' && sudo chmod +x $PROXMOX_ASSISTANT_PATH"
    fi
fi

# 5. Install dasel (multi-format data selector - used for TOML editing)
info "Installing dasel..."
if command -v dasel &> /dev/null; then
    info "dasel already installed, skipping..."
else
    brew install dasel
    info "✅ dasel installed via Homebrew"
fi

info "✅ Tool installation process for macOS complete."
