#!/usr/bin/env bash
#
# initialize-linux.sh - Initialize development environment for Project Brahmanda on Linux
#
# This script installs the necessary tools for Project Brahmanda on Debian/Ubuntu-based Linux.
# Tools installed: Terraform, 1Password CLI, pipx, Ansible, Proxmox Auto-Install Assistant, dasel
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly PROXMOX_DEB_URL="http://download.proxmox.com/debian/pve/dists/bookworm/pvetest/binary-amd64/proxmox-auto-install-assistant_8.4.6_amd64.deb"
readonly DASEL_VERSION="v2.8.1"
readonly DASEL_URL="https://github.com/TomWright/dasel/releases/download/${DASEL_VERSION}/dasel_linux_amd64"
readonly DASEL_PATH="/usr/local/bin/dasel"

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

# Check if command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Check if running on supported Linux distribution
validate_linux_distro() {
  [[ -f /etc/debian_version ]] || die "This script requires Debian/Ubuntu-based Linux"
  command_exists lsb_release || die "lsb_release command not found"
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# Install system prerequisites
install_prerequisites() {
  info "Installing prerequisites..."
  
  if dpkg -l | grep -qw gnupg && \
     dpkg -l | grep -qw software-properties-common && \
     dpkg -l | grep -qw wget && \
     dpkg -l | grep -qw curl && \
     dpkg -l | grep -qw xorriso; then
    info "Prerequisites already installed, skipping"
    return 0
  fi
  
  sudo apt-get update
  sudo apt-get install -y gnupg software-properties-common wget curl xorriso
  success "Prerequisites installed"
}

# Configure HashiCorp APT repository
configure_hashicorp_repo() {
  info "Configuring HashiCorp APT repository..."
  
  if [[ -f /etc/apt/sources.list.d/hashicorp.list ]] || \
     grep -q "apt.releases.hashicorp.com" /etc/apt/sources.list 2>/dev/null; then
    info "HashiCorp repository already configured, skipping"
    return 0
  fi
  
  wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
  
  success "HashiCorp repository configured"
}

# Configure 1Password APT repository
configure_1password_repo() {
  info "Configuring 1Password APT repository..."
  
  if [[ -f /etc/apt/sources.list.d/1password.list ]] || \
     grep -q "downloads.1password.com" /etc/apt/sources.list 2>/dev/null; then
    info "1Password repository already configured, skipping"
    return 0
  fi
  
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/1password-archive-keyring.gpg > /dev/null
  
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
    sudo tee /etc/apt/sources.list.d/1password.list
  
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol > /dev/null
  
  success "1Password repository configured"
}

# Install main tools (Terraform, 1Password CLI, pipx)
install_main_tools() {
  info "Installing Terraform, 1Password CLI, and pipx..."
  
  sudo apt-get update
  
  if dpkg -l | grep -qw terraform && \
     dpkg -l | grep -qw 1password-cli && \
     dpkg -l | grep -qw pipx; then
    info "Terraform, 1Password CLI, and pipx already installed, skipping"
    return 0
  fi
  
  sudo apt-get install -y terraform 1password-cli pipx
  success "Main tools installed"
}

# Install filesystem tools for USB formatting
install_filesystem_tools() {
  info "Installing filesystem tools (exfatprogs, ntfs-3g, dosfstools)..."
  
  if dpkg -l | grep -qw exfatprogs && \
     dpkg -l | grep -qw ntfs-3g && \
     dpkg -l | grep -qw dosfstools; then
    info "Filesystem tools already installed, skipping"
    return 0
  fi
  
  sudo apt-get install -y exfatprogs ntfs-3g dosfstools
  success "Filesystem tools installed"
}

# Configure pipx PATH
configure_pipx_path() {
  info "Configuring pipx PATH..."
  
  pipx ensurepath
  
  if grep -Fxq "export PATH=\"\$HOME/.local/bin:\$PATH\"" ~/.bashrc; then
    info "PATH already configured in ~/.bashrc"
    return 0
  fi
  
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  success "Added ~/.local/bin to PATH in ~/.bashrc"
}

# Install Ansible via pipx
install_ansible() {
  info "Installing Ansible via pipx..."
  
  if pipx list 2>/dev/null | grep -qE '(^| )(ansible|ansible-core)($| )'; then
    info "Ansible already installed via pipx, skipping"
    
    # Verify ansible binary is accessible
    command_exists ansible || die "Ansible binary not found in PATH after pipx installation"
    return 0
  fi
  
  # Try ansible first, fall back to ansible-core if it fails
  if ! pipx install ansible 2>/dev/null; then
    info "Failed to install 'ansible' package, trying 'ansible-core' instead"
    pipx install ansible-core
  fi
  
  # Verify ansible binary is accessible
  command_exists ansible || die "Ansible binary not found after installation"
  success "Ansible installed via pipx"
}

# Install Proxmox Auto-Install Assistant
install_proxmox_assistant() {
  info "Installing Proxmox Auto-Install Assistant..."
  
  if command_exists proxmox-auto-install-assistant; then
    info "Proxmox Auto-Install Assistant already installed, skipping"
    return 0
  fi
  
  local temp_deb="/tmp/proxmox-auto-install-assistant.deb"
  
  info "Downloading proxmox-auto-install-assistant..."
  if wget -q -O "$temp_deb" "$PROXMOX_DEB_URL"; then
    info "Installing package..."
    sudo dpkg -i "$temp_deb"
    rm -f "$temp_deb"
    success "Proxmox Auto-Install Assistant installed"
  else
    rm -f "$temp_deb"
    die "Failed to download proxmox-auto-install-assistant"
  fi
}

# Install dasel (TOML editor)
install_dasel() {
  info "Installing dasel..."
  
  if [[ -f "$DASEL_PATH" ]] && [[ -x "$DASEL_PATH" ]]; then
    info "dasel already installed at $DASEL_PATH, skipping"
    return 0
  fi
  
  info "Downloading dasel from GitHub..."
  sudo wget -q -O "$DASEL_PATH" "$DASEL_URL"
  sudo chmod +x "$DASEL_PATH"
  success "dasel installed to $DASEL_PATH"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  info "Starting tool installation for Linux..."
  
  # Validate environment
  validate_linux_distro
  
  # Install prerequisites
  install_prerequisites
  
  # Configure repositories
  configure_hashicorp_repo
  configure_1password_repo
  
  # Install tools
  install_main_tools
  configure_pipx_path
  install_ansible
  install_proxmox_assistant
  install_dasel
  install_filesystem_tools
  
  success "Tool installation process for Linux complete"
  info "⚠️  IMPORTANT: Please restart your terminal or run 'source ~/.bashrc' to update PATH"
}

main "$@"
