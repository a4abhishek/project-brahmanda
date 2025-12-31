#!/bin/bash
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

info "✅ Tool installation process for macOS complete."
