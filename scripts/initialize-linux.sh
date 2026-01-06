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
  
  local ubuntu_codename=$(lsb_release -cs)
  local repo_file="/etc/apt/sources.list.d/hashicorp.list"
  local expected_repo="deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${ubuntu_codename} main"
  
  # Check if repository exists and is correctly configured for current Ubuntu version
  if [[ -f "$repo_file" ]]; then
    local current_repo=$(cat "$repo_file" 2>/dev/null | grep -v '^#' | head -n1)
    
    if [[ "$current_repo" == "$expected_repo" ]]; then
      info "HashiCorp repository already correctly configured for ${ubuntu_codename}, skipping"
      return 0
    else
      info "HashiCorp repository configured for wrong Ubuntu version, reconfiguring for ${ubuntu_codename}..."
      sudo rm -f "$repo_file"
    fi
  fi
  
  # Install GPG key
  if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
    wget -O- https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  fi
  
  # Add repository for current Ubuntu version
  echo "$expected_repo" | sudo tee "$repo_file" > /dev/null
  
  success "HashiCorp repository configured for ${ubuntu_codename}"
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
  
  # Check if 1Password CLI and pipx need installation
  local install_1password=false
  local install_pipx=false
  
  dpkg -l | grep -qw 1password-cli || install_1password=true
  dpkg -l | grep -qw pipx || install_pipx=true
  
  # Install 1Password CLI and pipx if needed
  if $install_1password || $install_pipx; then
    local packages=""
    $install_1password && packages="$packages 1password-cli"
    $install_pipx && packages="$packages pipx"
    sudo apt-get install -y $packages
  fi
  
  # Check Terraform version requirement (>= 1.9.0)
  local required_version="1.9.0"
  local current_version=""
  
  if command_exists terraform; then
    current_version=$(terraform version -json 2>/dev/null | grep -oP '"terraform_version":\s*"\K[^"]+' || terraform version | head -n1 | grep -oP 'v\K[0-9.]+' || echo "0.0.0")
    
    if printf '%s\n%s\n' "$required_version" "$current_version" | sort -V -C 2>/dev/null; then
      info "Terraform $current_version already installed (>= $required_version), skipping"
    else
      info "Terraform $current_version is too old (< $required_version), upgrading..."
      info "Removing old Terraform installation..."
      sudo apt-get remove -y terraform || true
      sudo rm -f /usr/bin/terraform /usr/local/bin/terraform
      
      info "Installing latest Terraform from HashiCorp repository..."
      sudo apt-get update
      sudo apt-get install -y terraform
      
      # Verify installation
      local new_version=$(terraform version -json 2>/dev/null | grep -oP '"terraform_version":\s*"\K[^"]+' || terraform version | head -n1 | grep -oP 'v\K[0-9.]+' || echo "0.0.0")
      if printf '%s\n%s\n' "$required_version" "$new_version" | sort -V -C 2>/dev/null; then
        success "Terraform upgraded to $new_version"
      else
        die "Failed to upgrade Terraform. Current version: $new_version (required: >= $required_version)"
      fi
    fi
  else
    info "Installing Terraform..."
    sudo apt-get install -y terraform
    
    # Verify installation
    local installed_version=$(terraform version -json 2>/dev/null | grep -oP '"terraform_version":\s*"\K[^"]+' || terraform version | head -n1 | grep -oP 'v\K[0-9.]+' || echo "0.0.0")
    if printf '%s\n%s\n' "$required_version" "$installed_version" | sort -V -C 2>/dev/null; then
      success "Terraform $installed_version installed"
    else
      die "Terraform installation failed or version too old. Current: $installed_version (required: >= $required_version)"
    fi
  fi
  
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
