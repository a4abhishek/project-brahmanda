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
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

## 1Password
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor | sudo tee /usr/share/keyrings/1password-archive-keyring.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol

# 4. Install tools
info "Updating package lists from new repositories..."
sudo apt-get update

info "Installing Terraform, Ansible, and 1Password CLI..."
# apt-get install is idempotent; it will only install if the package is missing or needs an upgrade.
sudo apt-get install -y terraform ansible 1password-cli

info "✅ Tool installation process for Linux complete."
