#!/usr/bin/env bash
#
# initialize-macos.sh - Initialize development environment for Project Brahmanda on macOS
#
# This script installs the necessary tools for Project Brahmanda on macOS using Homebrew.
# Tools installed: Terraform, Ansible, 1Password CLI, Proxmox Auto-Install Assistant, dasel
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly PROXMOX_ASSISTANT_PATH="/usr/local/bin/proxmox-auto-install-assistant"
readonly PROXMOX_ASSISTANT_URL="https://git.proxmox.com/?p=pve-installer.git;a=blob_plain;f=proxmox-auto-install-assistant;hb=HEAD"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print error message and exit
die() {
  echo "❌ ERROR: $*" >&2
  exit 1
}

# Print info message
info() {
  echo "ℹ️  $*"
}

# Print success message
success() {
  echo "✅ $*"
}

# Print warning message
warn() {
  echo "⚠️  WARNING: $*"
}

# Check if command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Check if Homebrew is installed
validate_homebrew() {
  command_exists brew || die "Homebrew is not installed. Please install it first from https://brew.sh/"
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# Update Homebrew
update_homebrew() {
  info "Updating Homebrew..."
  brew update
  success "Homebrew updated"
}

# Install main tools via Homebrew
install_main_tools() {
  info "Installing Terraform, Ansible, and 1Password CLI..."
  
  # Check Terraform version requirement (>= 1.9.0)
  local required_version="1.9.0"
  local current_version=""
  
  if command_exists terraform; then
    current_version=$(terraform version -json 2>/dev/null | grep -oP '"terraform_version":\s*"\K[^"]+' || echo "0.0.0")
    
    if printf '%s\n%s\n' "$required_version" "$current_version" | sort -V -C 2>/dev/null; then
      info "Terraform $current_version already installed (>= $required_version), skipping"
    else
      info "Terraform $current_version is too old (< $required_version), upgrading..."
      brew upgrade terraform
    fi
  else
    info "Installing Terraform..."
    brew install terraform
  fi
  
  # Brew install is idempotent; it will only install if not already present
  brew install ansible 1password-cli
  success "Main tools installed"
}

# Install Proxmox Auto-Install Assistant
install_proxmox_assistant() {
  info "Installing Proxmox Auto-Install Assistant..."
  
  if [[ -f "$PROXMOX_ASSISTANT_PATH" ]] && [[ -x "$PROXMOX_ASSISTANT_PATH" ]]; then
    info "Proxmox Auto-Install Assistant already installed at $PROXMOX_ASSISTANT_PATH, skipping"
    return 0
  fi
  
  info "Downloading Proxmox Auto-Install Assistant from Proxmox Git..."
  
  if sudo curl --retry 3 --max-time 30 -fsSL -o "$PROXMOX_ASSISTANT_PATH" "$PROXMOX_ASSISTANT_URL" 2>/dev/null; then
    sudo chmod +x "$PROXMOX_ASSISTANT_PATH"
    success "Proxmox Auto-Install Assistant installed to $PROXMOX_ASSISTANT_PATH"
  else
    warn "Failed to download Proxmox Auto-Install Assistant"
    warn "This tool is optional. You can continue without it."
    warn "To install manually: sudo curl -fsSL -o $PROXMOX_ASSISTANT_PATH '$PROXMOX_ASSISTANT_URL' && sudo chmod +x $PROXMOX_ASSISTANT_PATH"
  fi
}

# Install dasel (TOML editor)
install_dasel() {
  info "Installing dasel..."
  
  if command_exists dasel; then
    info "dasel already installed, skipping"
    return 0
  fi
  
  brew install dasel
  success "dasel installed via Homebrew"
}

# Install filesystem tools for USB formatting
install_filesystem_tools() {
  info "Installing filesystem tools (exfat, ntfs-3g, dosfstools)..."
  
  # Brew install is idempotent; it will only install if not already present
  brew install exfat ntfs-3g dosfstools
  success "Filesystem tools installed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  info "Starting tool installation for macOS..."
  
  # Validate environment
  validate_homebrew
  
  # Update Homebrew
  update_homebrew
  
  # Install tools
  install_main_tools
  install_proxmox_assistant
  install_dasel
  install_filesystem_tools
  
  success "Tool installation process for macOS complete"
}

main "$@"
