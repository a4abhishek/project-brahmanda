#!/bin/bash
#
# initialize-linux.sh - Initialize development environment for Project Brahmanda on Linux
#
# This script installs the necessary tools for Project Brahmanda on Debian/Ubuntu-based Linux.

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to print messages
info() {
    echo "INFO: $1"
}

info "Starting tool installation for Linux..."

# 1. Install prerequisites
info "Installing prerequisites..."
if dpkg -l | grep -qw gnupg && dpkg -l | grep -qw software-properties-common && dpkg -l | grep -qw wget && dpkg -l | grep -qw curl; then
    info "Prerequisites already installed, skipping..."
else
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common wget curl
fi

# 2. Configure APT repositories
info "Configuring third-party APT repositories..."

## HashiCorp (for Terraform)
if [ ! -f /etc/apt/sources.list.d/hashicorp.list ] && ! grep -q "apt.releases.hashicorp.com" /etc/apt/sources.list 2>/dev/null; then
    info "Adding HashiCorp APT repository..."
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
else
    info "HashiCorp repository already configured, skipping..."
fi

## 1Password
if [ ! -f /etc/apt/sources.list.d/1password.list ] && ! grep -q "downloads.1password.com" /etc/apt/sources.list 2>/dev/null; then
    info "Adding 1Password APT repository..."
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor | sudo tee /usr/share/keyrings/1password-archive-keyring.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
else
    info "1Password repository already configured, skipping..."
fi

# 4. Install tools
info "Updating package lists..."
sudo apt-get update

info "Installing Terraform, 1Password CLI, and pipx..."
if dpkg -l | grep -qw terraform && dpkg -l | grep -qw 1password-cli && dpkg -l | grep -qw pipx; then
    info "Terraform, 1Password CLI, and pipx already installed, skipping..."
else
    sudo apt-get install -y terraform 1password-cli pipx
fi

info "Configuring pipx PATH..."
pipx ensurepath
if ! grep -Fxq "export PATH=\"$HOME/.local/bin:\$PATH\"" ~/.bashrc; then
    info "Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
    info "PATH already configured in ~/.bashrc"
fi

info "Installing Ansible via pipx (isolated environment)..."
if pipx list 2>/dev/null | grep -qE '(^| )(ansible|ansible-core)($| )'; then
    info "Ansible already installed via pipx, skipping..."
    # Verify ansible binary is accessible
    if ! command -v ansible &> /dev/null; then
        info "⚠️  'ansible' binary not found in PATH after pipx installation."
        info "   This is unexpected. Please check pipx installation."
        exit 1
    fi
else
    # Try ansible first, fall back to ansible-core if it fails
    if ! pipx install ansible 2>/dev/null; then
        info "⚠️  Failed to install 'ansible' package, trying 'ansible-core' instead..."
        pipx install ansible-core
    fi
    # Verify ansible binary is accessible
    if ! command -v ansible &> /dev/null; then
        info "⚠️  'ansible' binary not found after installation."
        exit 1
    fi
fi

# 5. Install Proxmox Auto-Install Assistant
# Available from Proxmox repository: https://pve.proxmox.com/wiki/Automated_Installation#Assistant_Tool
info "Installing Proxmox Auto-Install Assistant..."

if command -v proxmox-auto-install-assistant &> /dev/null; then
    info "Proxmox Auto-Install Assistant already installed, skipping..."
else
    # Add Proxmox repository if not present
    if [ ! -f /etc/apt/sources.list.d/proxmox.list ] && ! grep -q "download.proxmox.com" /etc/apt/sources.list 2>/dev/null; then
        info "Adding Proxmox repository..."
        echo "deb http://download.proxmox.com/debian/pve $(lsb_release -sc) pvetest" | sudo tee /etc/apt/sources.list.d/proxmox.list
        # Add Proxmox VE repository key
        wget -O- "https://enterprise.proxmox.com/debian/proxmox-release-$(lsb_release -sc).gpg" | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/proxmox-release-$(lsb_release -sc).gpg 2>/dev/null || true
        sudo apt-get update
    fi
    
    info "Installing proxmox-auto-install-assistant via apt..."
    if sudo apt-get install -y proxmox-auto-install-assistant 2>/dev/null; then
        info "✅ Proxmox Auto-Install Assistant installed via apt"
    else
        info "⚠️  Failed to install via apt, trying direct download from Proxmox Git..."
        PROXMOX_ASSISTANT_URL="https://git.proxmox.com/?p=pve-installer.git;a=blob_plain;f=proxmox-auto-install-assistant;hb=HEAD"
        PROXMOX_ASSISTANT_PATH="/usr/local/bin/proxmox-auto-install-assistant"
        
        if sudo wget --tries=3 --timeout=30 -O "$PROXMOX_ASSISTANT_PATH" "$PROXMOX_ASSISTANT_URL" 2>/dev/null; then
            sudo chmod +x "$PROXMOX_ASSISTANT_PATH"
            info "✅ Proxmox Auto-Install Assistant installed from Git"
        else
            echo "ERROR: Failed to install Proxmox Auto-Install Assistant"
            echo "This tool is optional. You can continue without it."
            echo "To install manually: sudo apt-get install proxmox-auto-install-assistant"
        fi
    fi
fi

# 6. Install dasel (multi-format data selector - used for TOML editing)
info "Installing dasel..."
DASEL_PATH="/usr/local/bin/dasel"

if [ -f "$DASEL_PATH" ] && [ -x "$DASEL_PATH" ]; then
    info "dasel already installed at $DASEL_PATH, skipping..."
else
    info "Downloading dasel from GitHub..."
    DASEL_VERSION="v2.8.1"
    DASEL_URL="https://github.com/TomWright/dasel/releases/download/${DASEL_VERSION}/dasel_linux_amd64"
    sudo wget -q -O "$DASEL_PATH" "$DASEL_URL"
    sudo chmod +x "$DASEL_PATH"
    info "✅ dasel installed to $DASEL_PATH"
fi

info "✅ Tool installation process for Linux complete."
info "⚠️  IMPORTANT: Please restart your terminal or run 'source ~/.bashrc' to update PATH."
