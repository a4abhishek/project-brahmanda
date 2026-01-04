#!/bin/bash
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
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common wget curl

# 2. Configure APT repositories
info "Configuring third-party APT repositories..."

## HashiCorp (for Terraform)
if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
fi

## 1Password
if [ ! -f /etc/apt/sources.list.d/1password.list ]; then
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor | sudo tee /usr/share/keyrings/1password-archive-keyring.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
fi

# 4. Install tools
info "Updating package lists from new repositories..."
sudo apt-get update

info "Installing Terraform, 1Password CLI, and pipx..."
sudo apt-get install -y terraform 1password-cli pipx

info "Configuring pipx PATH..."
pipx ensurepath
if ! grep -Fxq "export PATH=\"$HOME/.local/bin:\$PATH\"" ~/.bashrc; then
    info "Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
    info "PATH already configured in ~/.bashrc"
fi

info "Installing Ansible via pipx (isolated environment)..."
if pipx list | grep -q ansible; then
    info "Ansible already installed via pipx, upgrading..."
    pipx upgrade ansible
else
    pipx install ansible
fi

# Verify ansible binary is accessible
if ! command -v ansible &> /dev/null; then
    info "⚠️  'ansible' binary not found after installation. Reinstalling with ansible-core..."
    pipx uninstall ansible
    pipx install ansible-core
fi

info "✅ Tool installation process for Linux complete."
info "⚠️  IMPORTANT: Please restart your terminal or run 'source ~/.bashrc' to update PATH."
