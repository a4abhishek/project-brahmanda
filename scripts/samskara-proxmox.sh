#!/usr/bin/env bash
#
# samskara-proxmox.sh - Samskara (Purification/Refinement)
#
# Refines base Proxmox VE installation into production-ready state:
# 1. Configures community repositories (disables enterprise repos)
# 2. Updates package lists and upgrades packages
# 3. Disables subscription popup (default, use --keep-subscription-popup to preserve)
#
# Usage:
#   ./samskara-proxmox.sh [--keep-subscription-popup]
#
# This script is idempotent - safe to run multiple times.
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly PVE_ENTERPRISE_LIST="/etc/apt/sources.list.d/pve-enterprise.list"
readonly CEPH_ENTERPRISE_LIST="/etc/apt/sources.list.d/ceph.list"
readonly PVE_NO_SUB_LIST="/etc/apt/sources.list.d/pve-no-subscription.list"
readonly PROXMOX_WIDGET_DIR="/usr/share/javascript/proxmox-widget-toolkit"
readonly PROXMOX_LIB_JS="${PROXMOX_WIDGET_DIR}/proxmoxlib.js"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

KEEP_POPUP=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

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
  echo "⚠️  $*"
}

# Print error message and exit
die() {
  echo "❌ ERROR: $*" >&2
  exit 1
}

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root. Use: sudo $SCRIPT_NAME"
  fi
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --keep-subscription-popup)
        KEEP_POPUP=true
        shift
        ;;
      -h|--help)
        echo "Usage: $SCRIPT_NAME [--keep-subscription-popup]"
        echo ""
        echo "Options:"
        echo "  --keep-subscription-popup    Keep the 'No valid subscription' popup (for legal compliance)"
        echo "  -h, --help                   Show this help message"
        echo ""
        echo "By default, the subscription popup is disabled for Community Edition users."
        exit 0
        ;;
      *)
        die "Unknown argument: $1. Use -h for help."
        ;;
    esac
  done
}

# ============================================================================
# REPOSITORY CONFIGURATION
# ============================================================================

# Disable enterprise repositories
disable_enterprise_repos() {
  info "Configuring Proxmox repositories..."
  
  local changed=false
  
  # Disable PVE enterprise repository
  if [[ -f "$PVE_ENTERPRISE_LIST" ]]; then
    info "Disabling PVE enterprise repository..."
    mv "$PVE_ENTERPRISE_LIST" "${PVE_ENTERPRISE_LIST}.disabled"
    success "PVE enterprise repository disabled"
    changed=true
  else
    if [[ -f "${PVE_ENTERPRISE_LIST}.disabled" ]]; then
      success "PVE enterprise repository already disabled"
    else
      info "PVE enterprise repository not found (already removed or never existed)"
    fi
  fi
  
  # Disable Ceph enterprise repository
  if [[ -f "$CEPH_ENTERPRISE_LIST" ]]; then
    info "Disabling Ceph enterprise repository..."
    mv "$CEPH_ENTERPRISE_LIST" "${CEPH_ENTERPRISE_LIST}.disabled"
    success "Ceph enterprise repository disabled"
    changed=true
  else
    if [[ -f "${CEPH_ENTERPRISE_LIST}.disabled" ]]; then
      success "Ceph enterprise repository already disabled"
    else
      info "Ceph enterprise repository not found (already removed or never exists)"
    fi
  fi
  
  return 0
}

# Enable community (no-subscription) repository
enable_community_repo() {
  if [[ -f "$PVE_NO_SUB_LIST" ]]; then
    # Verify content is correct
    if grep -q "pve-no-subscription" "$PVE_NO_SUB_LIST"; then
      success "Community repository already configured"
      return 0
    else
      warn "Community repository file exists but has incorrect content, recreating..."
    fi
  fi
  
  info "Adding community (no-subscription) repository..."
  echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > "$PVE_NO_SUB_LIST"
  success "Community repository added"
}

# ============================================================================
# PACKAGE MANAGEMENT
# ============================================================================

# Update package lists
update_packages() {
  info "Updating package lists..."
  
  if apt-get update 2>&1 | tee /tmp/apt-update.log | grep -q "401.*Unauthorized"; then
    warn "Still seeing 401 errors - enterprise repositories may not be fully disabled"
    cat /tmp/apt-update.log
    return 1
  fi
  
  success "Package lists updated successfully"
  rm -f /tmp/apt-update.log
}

# Upgrade packages
upgrade_packages() {
  info "Upgrading packages (this may take a few minutes)..."
  
  # Check if upgrades are available
  if apt-get -s dist-upgrade | grep -q "0 upgraded"; then
    success "System is already up to date"
    return 0
  fi
  
  # Perform upgrade
  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
  success "System upgraded successfully"
}

# ============================================================================
# SUBSCRIPTION POPUP
# ============================================================================

# Disable subscription popup
disable_subscription_popup() {
  if [[ "$KEEP_POPUP" == "true" ]]; then
    info "Keeping subscription popup (--keep-subscription-popup specified)"
    return 0
  fi
  
  info "Disabling subscription popup..."
  
  if [[ ! -f "$PROXMOX_LIB_JS" ]]; then
    warn "Proxmox widget toolkit not found at $PROXMOX_LIB_JS - skipping popup disable"
    return 0
  fi
  
  # Check if already disabled
  if grep -q "void.*No valid subscription" "$PROXMOX_LIB_JS"; then
    success "Subscription popup already disabled"
    return 0
  fi
  
  # Backup original file if not already backed up (idempotent)
  if [[ ! -f "${PROXMOX_LIB_JS}.bak" ]]; then
    cp "$PROXMOX_LIB_JS" "${PROXMOX_LIB_JS}.bak"
    info "Created backup: ${PROXMOX_LIB_JS}.bak"
  else
    info "Backup already exists: ${PROXMOX_LIB_JS}.bak"
  fi
  
  # Disable the popup
  sed -i '/No valid subscription/,/callback: function(btn)/s/Ext\.Msg\.show/void/' "$PROXMOX_LIB_JS"
  
  # Restart web interface
  systemctl restart pveproxy
  
  success "Subscription popup disabled (web interface restarted)"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  echo ""
  echo "🕉️  Samskara (Purification) - Proxmox Refinement"
  echo "================================================"
  echo ""
  
  # Parse arguments
  parse_arguments "$@"
  
  # Check root privileges
  check_root
  
  # Configure repositories
  disable_enterprise_repos
  enable_community_repo
  
  # Update and upgrade
  update_packages
  upgrade_packages
  
  # Disable subscription popup (if requested)
  disable_subscription_popup
  
  # Summary
  echo ""
  echo "============================================="
  success "Samskara complete - system refined and purified!"
  echo ""
  
  if [[ "$KEEP_POPUP" == "true" ]]; then
    info "Subscription popup preserved (for legal compliance)"
  else
    info "Subscription popup disabled (Community Edition)"
  fi
  
  info "Proxmox VE is now ready for use"
  info "Web UI: https://$(hostname -I | awk '{print $1}'):8006"
  echo ""
}

# Run main function with all arguments
main "$@"
