#!/usr/bin/env bash
#
# pratistha-proxmox.sh - Automated Proxmox VE Installation Preparation
#
# This script automates the entire Proxmox installation workflow:
# 1. Downloads Proxmox ISO with progress
# 2. Validates/generates SSH keys
# 3. Retrieves credentials from 1Password
# 4. Generates answer.local.toml from template
# 5. Creates bootable USB using proxmox-auto-install-assistant
#
# Usage:
#   ./pratistha-proxmox.sh \
#     --iso-version 9.1-1 \
#     --root-password "$(op read 'op://Project-Brahmanda/Proxmox Brahmanda Root Password/password')" \
#     --ssh-key-path ~/.ssh/proxmox-brahmanda.pub \
#     --usb-device /dev/sdb \
#     [--skip-download] \
#     [--force] \
#     [--verify-usb]
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ISO_BASE_URL="https://enterprise.proxmox.com/iso"
readonly TEMPLATE_FILE="${PROJECT_ROOT}/samsara/proxmox/answer.toml"
readonly OUTPUT_FILE="${PROJECT_ROOT}/samsara/proxmox/answer.local.toml"
readonly ISO_DIR="${PROJECT_ROOT}/.cache/iso"
readonly MIN_ISO_SIZE=104857600  # 100MB

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

ISO_VERSION="9.1-1"
SSH_KEY_PATH="${HOME}/.ssh/proxmox-brahmanda.pub"
SKIP_DOWNLOAD=false
FORCE=false
VERIFY_USB=false
ROOT_PASSWORD=""
USB_DEVICE=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print error message and exit
# Arguments:
#   $1 - Error message
die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Print info message
# Arguments:
#   $1 - Info message
info() {
  echo "$*"
}

# Print success message
# Arguments:
#   $1 - Success message
success() {
  echo "✅ $*"
}

# Print warning message
# Arguments:
#   $1 - Warning message
warn() {
  echo "⚠️  WARNING: $*"
}

# Check if command exists
# Arguments:
#   $1 - Command name
# Returns:
#   0 if command exists, 1 otherwise
command_exists() {
  command -v "$1" &>/dev/null
}

# Prompt user for yes/no confirmation
# Arguments:
#   $1 - Prompt message
# Returns:
#   0 if user answered yes, 1 otherwise
confirm() {
  local prompt="$1"
  local reply
  read -rp "${prompt} [y/N]: " -n 1 reply
  echo
  [[ $reply =~ ^[Yy]$ ]]
}

# Check if running in WSL
# Returns:
#   0 if running in WSL, 1 otherwise
is_wsl() {
  [[ -f /proc/version ]] && grep -qi microsoft /proc/version
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --iso-version)
        ISO_VERSION="$2"
        shift 2
        ;;
      --root-password)
        ROOT_PASSWORD="$2"
        shift 2
        ;;
      --ssh-key-path)
        SSH_KEY_PATH="$2"
        shift 2
        ;;
      --usb-device)
        USB_DEVICE="$2"
        shift 2
        ;;
      --skip-download)
        SKIP_DOWNLOAD=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --verify-usb)
        VERIFY_USB=true
        shift
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Validate that USB device is provided
validate_usb_device_provided() {
  [[ -n "$USB_DEVICE" ]] || die "--usb-device is required"
}

# Validate USB device exists and is accessible
validate_usb_device_exists() {
  if ! lsblk "$USB_DEVICE" >/dev/null 2>&1; then
    # Show WSL-specific instructions if needed
    if is_wsl; then
      echo ""
      warn "WSL ENVIRONMENT DETECTED"
      info "USB device not found. In WSL, you must attach the USB bus first."
      echo ""
      info "In a NEW Windows Terminal with ADMIN privileges, run:"
      info "  1. List USB devices:    usbipd list"
      info "  2. Find your USB bus ID (e.g., 2-13)"
      info "  3. Attach to WSL:       usbipd attach --wsl --busid <BUS-ID>"
      echo ""
      info "Example: usbipd attach --wsl --busid 2-13"
      echo ""
      info "Then re-run this script."
      echo ""
    fi
    
    info "Available devices:"
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT
    die "USB device $USB_DEVICE not found or inaccessible"
  fi
}

# Validate USB device is a disk (not a partition)
validate_usb_device_is_disk() {
  local device_type
  device_type=$(lsblk -dno TYPE "$USB_DEVICE" 2>/dev/null || echo "unknown")
  
  if [[ "$device_type" != "disk" ]]; then
    die "$USB_DEVICE is not a disk device (type: $device_type). Please specify the disk device (e.g., /dev/sdb), not a partition (e.g., /dev/sdb1)"
  fi
}

# Validate USB device is removable
validate_usb_device_is_removable() {
  local is_removable
  is_removable=$(lsblk -dno RM "$USB_DEVICE" 2>/dev/null || echo "0")
  
  if [[ "$is_removable" != "1" ]]; then
    die "$USB_DEVICE is not a removable device (RM=$is_removable). For safety, this script only writes to removable media (USB drives, SD cards). If you're certain this is the correct device, you can bypass this check by modifying the script."
  fi
}

# Check if USB device is already a Proxmox auto-install medium
# Returns:
#   0 if already configured, 1 otherwise
check_usb_already_configured() {
  # Proxmox auto-install USB has 4 partitions (ISO9660 structure)
  local partition_count
  partition_count=$(lsblk -ln -o TYPE "$USB_DEVICE" | grep -c "^part$" || echo 0)
  
  if [[ "$partition_count" -ge 4 ]]; then
    return 0
  fi
  
  return 1
}

# Validate required tools are installed
validate_required_tools() {
  command_exists dasel || die "dasel not found. Required for TOML editing. Install via: make init"
  command_exists proxmox-auto-install-assistant || die "proxmox-auto-install-assistant not found. Install via: make init"
}

# Validate 1Password CLI authentication (if password not provided)
validate_onepassword_auth() {
  # Skip if password already provided
  [[ -n "$ROOT_PASSWORD" ]] && return 0
  
  info "🔐 Checking 1Password CLI authentication..."
  
  command_exists op || die "1Password CLI not found. Install or provide --root-password"
  
  if ! op account get &>/dev/null; then
    echo ""
    warn "1Password CLI not authenticated"
    echo ""
    info "To retrieve ROOT_PASSWORD from 1Password, you must sign in FIRST:"
    info ""
    info "  Step 1: Sign in to 1Password in your shell"
    info "    $ eval \$(op signin)"
    info ""
    info "  Step 2: Re-run the make command with ROOT_PASSWORD"
    info "    $ make pratistha ROOT_PASSWORD=\"\\\$(op read 'op://Project-Brahmanda/...')\" USB_DEVICE=..."
    echo ""
    info "NOTE: The '\$(op read ...)' command runs in YOUR SHELL before the script starts,"
    info "      so you must be signed in for it to retrieve the password."
    echo ""
    die "1Password authentication required"
  fi
  
  success "1Password CLI already authenticated"
}

# ============================================================================
# SSH KEY FUNCTIONS
# ============================================================================

# Check and generate SSH keys if needed
# Sets global variable: SSH_PUBLIC_KEY
validate_or_generate_ssh_keys() {
  info "📋 Step 1/5: Validating SSH keys..."
  
  local ssh_private_key="${SSH_KEY_PATH%.pub}"
  
  if [[ -f "$SSH_KEY_PATH" ]]; then
    success "SSH public key found: $SSH_KEY_PATH"
    
    if [[ ! -f "$ssh_private_key" ]]; then
      warn "Public key exists but private key missing at $ssh_private_key"
      warn "You may have authentication issues. Consider regenerating the key pair."
    fi
  else
    info "SSH public key not found at $SSH_KEY_PATH"
    
    if confirm "Generate new Ed25519 key pair?"; then
      info "Generating SSH key pair..."
      mkdir -p "$(dirname "$ssh_private_key")"
      ssh-keygen -t ed25519 -C "proxmox-brahmanda-root" -f "$ssh_private_key" -N "" || die "Failed to generate SSH keys"
      success "SSH keys generated:"
      info "   Private: $ssh_private_key"
      info "   Public:  $SSH_KEY_PATH"
    else
      die "SSH key required. Exiting."
    fi
  fi
  
  SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")
}

# ============================================================================
# PASSWORD FUNCTIONS
# ============================================================================

# Retrieve root password from 1Password if not provided
validate_or_retrieve_password() {
  info "📋 Step 2/5: Validating root password..."
  
  if [[ -z "$ROOT_PASSWORD" ]]; then
    info "Root password not provided. Retrieving from 1Password..."
    
    ROOT_PASSWORD=$(op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password")
    [[ -n "$ROOT_PASSWORD" ]] || die "Failed to retrieve password from 1Password"
  fi
  
  success "Root password validated (length: ${#ROOT_PASSWORD} chars)"
}

# ============================================================================
# ISO FUNCTIONS
# ============================================================================

# Download or validate Proxmox ISO
# Sets global variable: ISO_PATH
download_or_validate_iso() {
  info "📋 Step 3/5: Preparing Proxmox ISO..."
  
  local iso_filename="proxmox-ve_${ISO_VERSION}.iso"
  ISO_PATH="${ISO_DIR}/${iso_filename}"
  
  if [[ "$SKIP_DOWNLOAD" == "true" ]] && [[ -f "$ISO_PATH" ]]; then
    success "Skipping download (--skip-download). Using existing: $ISO_PATH"
    return 0
  fi
  
  if [[ -f "$ISO_PATH" ]]; then
    info "ISO already exists: $ISO_PATH"
    if ! confirm "Re-download?"; then
      success "Using existing ISO"
      return 0
    fi
    rm -f "$ISO_PATH"
  fi
  
  download_iso "$iso_filename"
  validate_iso_integrity
}

# Download ISO from Proxmox repository
# Arguments:
#   $1 - ISO filename
download_iso() {
  local iso_filename="$1"
  local iso_url="${ISO_BASE_URL}/${iso_filename}"
  
  mkdir -p "$ISO_DIR"
  info "Downloading ${iso_filename}..."
  
  if command_exists curl; then
    curl -# -L -o "$ISO_PATH" "$iso_url" || {
      rm -f "$ISO_PATH"
      die "Failed to download ISO from $iso_url"
    }
  elif command_exists wget; then
    wget --progress=bar:force -O "$ISO_PATH" "$iso_url" || {
      rm -f "$ISO_PATH"
      die "Failed to download ISO from $iso_url"
    }
  else
    die "Neither curl nor wget found. Cannot download ISO."
  fi
}

# Validate ISO file integrity
validate_iso_integrity() {
  [[ -f "$ISO_PATH" ]] || die "ISO file not found after download"
  
  local iso_size
  iso_size=$(stat -f%z "$ISO_PATH" 2>/dev/null || stat -c%s "$ISO_PATH" 2>/dev/null || echo "0")
  
  if [[ "$iso_size" -lt "$MIN_ISO_SIZE" ]]; then
    rm -f "$ISO_PATH"
    die "Downloaded ISO appears corrupted (size: $iso_size bytes, expected >100MB)"
  fi
  
  success "ISO downloaded: $ISO_PATH (${iso_size} bytes)"
}

# ============================================================================
# ANSWER FILE FUNCTIONS
# ============================================================================

# Generate answer.local.toml from template
generate_answer_file() {
  info "📋 Step 4/5: Generating answer.local.toml..."
  
  [[ -f "$TEMPLATE_FILE" ]] || die "Template file not found: $TEMPLATE_FILE"
  
  check_existing_answer_file
  copy_template_and_inject_secrets
  validate_generated_answer_file
  
  success "Configuration generated: $OUTPUT_FILE"
  info "   Root password: [HASHED]"
  info "   SSH public key: ${SSH_PUBLIC_KEY:0:40}..."
}

# Check if existing answer file is valid
check_existing_answer_file() {
  if [[ ! -f "$OUTPUT_FILE" ]]; then
    return 0
  fi
  
  if proxmox-auto-install-assistant validate-answer "$OUTPUT_FILE" &>/dev/null; then
    if grep -qF "$SSH_PUBLIC_KEY" "$OUTPUT_FILE" 2>/dev/null; then
      success "Configuration file already exists and is valid: $OUTPUT_FILE"
      info "   Regenerating to ensure password is current..."
    else
      warn "Existing configuration has different SSH key, regenerating..."
    fi
  else
    warn "Existing configuration failed validation, regenerating..."
  fi
}

# Copy template and inject secrets
copy_template_and_inject_secrets() {
  cp "$TEMPLATE_FILE" "$OUTPUT_FILE"
  
  # Set root password (PLAINTEXT - Proxmox will hash it during installation)
  dasel put -f "$OUTPUT_FILE" -r toml -t string -v "$ROOT_PASSWORD" 'global.root_password' || \
    die "Failed to set root_password in answer.local.toml"
  
  # Set SSH keys (delete existing first, then append)
  dasel delete -f "$OUTPUT_FILE" -r toml 'global.root_ssh_keys' 2>/dev/null || true
  dasel put -f "$OUTPUT_FILE" -r toml -t string -v "$SSH_PUBLIC_KEY" 'global.root_ssh_keys.[]' || \
    die "Failed to set root_ssh_keys in answer.local.toml"
}

# Validate generated answer file
validate_generated_answer_file() {
  # Validate with proxmox-auto-install-assistant
  if ! proxmox-auto-install-assistant validate-answer "$OUTPUT_FILE" &>/dev/null; then
    info "Answer file validation failed. Details:"
    proxmox-auto-install-assistant validate-answer "$OUTPUT_FILE"
    die "Generated answer file failed validation"
  fi
  
  # Verify required fields are present
  dasel -f "$OUTPUT_FILE" -r toml 'global.root_password' &>/dev/null || \
    die "Failed to generate $OUTPUT_FILE correctly (missing root_password)"
  
  dasel -f "$OUTPUT_FILE" -r toml 'global.root_ssh_keys.[0]' &>/dev/null || \
    die "Failed to generate $OUTPUT_FILE correctly (missing root_ssh_keys)"
}

# ============================================================================
# USB CREATION FUNCTIONS
# ============================================================================

# Create bootable USB drive
create_bootable_usb() {
  info "📋 Step 5/5: Creating bootable USB drive..."
  
  prompt_user_confirmation
  unmount_usb_partitions
  create_auto_install_iso
  write_iso_to_usb
  
  # Verify USB device only if verification is enabled
  # (verification requires USB to be replugged to detect partitions properly)
  if [[ "$VERIFY_USB" == "true" ]]; then
    verify_usb_device
  else
    success "USB creation complete (verification skipped - use --verify-usb to enable)"
  fi
  
  cleanup_temp_files
}

# Prompt user for confirmation before writing to USB
prompt_user_confirmation() {
  warn "This will ERASE ALL DATA on $USB_DEVICE"
  lsblk "$USB_DEVICE"
  
  confirm "Continue?" || die "Aborted by user."
}

# Unmount any mounted partitions on USB device
unmount_usb_partitions() {
  info "Checking for mounted partitions..."
  
  local mounted_parts
  mounted_parts=$(lsblk -no MOUNTPOINT "$USB_DEVICE" 2>/dev/null | grep -v '^$' || true)
  
  if [[ -z "$mounted_parts" ]]; then
    return 0
  fi
  
  info "Unmounting partitions on $USB_DEVICE..."
  local part_name part_path
  
  while IFS= read -r part_name; do
    [[ "$part_name" == "$(basename "$USB_DEVICE")" ]] && continue
    
    part_path="/dev/$part_name"
    if mountpoint -q "$(lsblk -no MOUNTPOINT "$part_path" 2>/dev/null || echo '')"; then
      sudo umount "$part_path" 2>/dev/null || true
    fi
  done < <(lsblk -lno NAME "$USB_DEVICE")
  
  success "Partitions unmounted"
}

# Create auto-install ISO with embedded answer file
# Sets global variable: TMP_ISO
create_auto_install_iso() {
  TMP_ISO="/tmp/proxmox-auto-${ISO_VERSION}.iso"
  
  info "Creating bootable installation medium..."
  
  sudo proxmox-auto-install-assistant prepare-iso \
    "$ISO_PATH" \
    --fetch-from iso \
    --answer-file "$OUTPUT_FILE" \
    --output "$TMP_ISO" || {
      # Cleanup with sudo - file was created with elevated privileges
      [[ -f "$TMP_ISO" ]] && sudo rm -f "$TMP_ISO"
      die "Failed to create bootable ISO with proxmox-auto-install-assistant"
    }
  
  [[ -f "$TMP_ISO" ]] || die "Bootable ISO not created at $TMP_ISO"
}

# Write ISO to USB device
write_iso_to_usb() {
  info "Writing ISO to USB device..."
  
  sudo dd if="$TMP_ISO" of="$USB_DEVICE" bs=4M status=progress oflag=sync || {
    # Cleanup with sudo - file was created with elevated privileges
    [[ -f "$TMP_ISO" ]] && sudo rm -f "$TMP_ISO"
    die "Failed to write ISO to USB device"
  }
  
  info "Syncing filesystems..."
  sync
  
  # Force kernel to re-read partition table
  info "Refreshing device information..."
  sudo blockdev --rereadpt "$USB_DEVICE" 2>/dev/null || true
  sleep 2  # Give system time to recognize new partitions
}

# Verify USB device has been created correctly
verify_usb_device() {
  info "Verifying bootable USB..."
  
  # Check for 4 partitions (Proxmox auto-install ISO structure)
  local partition_count
  partition_count=$(lsblk -ln -o TYPE "$USB_DEVICE" | grep -c "^part$" || echo 0)
  
  if [[ "$partition_count" -ge 4 ]]; then
    success "USB device verified successfully ($partition_count partitions created)"
  else
    warn "Expected 4 partitions, found $partition_count"
    warn "The USB creation may have failed"
  fi
  
  # Prompt user to remove and reinsert USB
  echo ""
  info "⚠️  IMPORTANT: Please remove and reinsert the USB drive now"
  info "   This ensures the system recognizes the new partition table"
  echo ""
  if ! confirm "Have you removed and reinserted the USB?"; then
    warn "Skipping USB reinsertion - device may not be properly recognized"
  else
    success "USB reinserted - device should now be fully recognized"
  fi
}

# Cleanup temporary files
cleanup_temp_files() {
  info "Cleaning up..."
  
  # ISO was created with sudo, so need sudo to remove it
  if [[ -f "$TMP_ISO" ]]; then
    sudo rm -f "$TMP_ISO"
  fi
}

# Eject USB device
eject_usb() {
  info "Ejecting USB device..."
  
  if command_exists eject; then
    if sudo eject "$USB_DEVICE" 2>/dev/null; then
      success "USB device ejected successfully"
      info "You can now safely remove the USB drive"
    else
      warn "Failed to eject USB device automatically"
      info "Please manually eject: sudo eject $USB_DEVICE"
    fi
  else
    info "'eject' command not found - skipping automatic ejection"
    info "Please manually eject: sudo eject $USB_DEVICE"
  fi
}

# ============================================================================
# SUCCESS MESSAGES
# ============================================================================

# Print success message with next steps
print_success_message() {
  echo ""
  success "SUCCESS: Pratistha complete!"
  echo ""
  info "Next Steps:"
  info "  1. Physically remove the USB drive (already ejected)"
  info "  2. Boot ASUS NUC from USB"
  info "  3. Proxmox will install automatically using answer.local.toml"
  info "  4. After installation, access Web UI: https://proxmox.brahmanda.local:8006"
  info "  5. SSH access: ssh root@proxmox.brahmanda.local"
  echo ""
}

# Print message when USB is already configured
print_already_configured_message() {
  success "USB device appears to be a Proxmox auto-install medium"
  info "   All steps complete - USB is ready for installation!"
  echo ""
  info "Next Steps:"
  info "  1. Safely eject USB: sudo eject $USB_DEVICE"
  info "  2. Boot ASUS NUC from USB"
  info "  3. Proxmox will install automatically"
  info "  4. After installation, access Web UI: https://proxmox.brahmanda.local:8006"
  info "  5. SSH access: ssh root@proxmox.brahmanda.local"
  echo ""
  info "To view device information: proxmox-auto-install-assistant device-info"
  info "To force regeneration, reformat the USB device first."
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  # Parse command-line arguments
  parse_arguments "$@"
  
  # Validate USB device
  validate_usb_device_provided
  validate_usb_device_exists
  validate_usb_device_is_disk
  validate_usb_device_is_removable
  
  # Check if USB is already configured (early exit optimization)
  if [[ "$FORCE" == "true" ]]; then
    info "🔄 Force flag set - skipping bootable check, will regenerate USB"
  else
    info "🔍 Checking if USB device is already bootable..."
    if check_usb_already_configured; then
      print_already_configured_message
      exit 0
    fi
    info "ℹ️  USB device is not configured for auto-install, proceeding with setup..."
  fi
  
  # Validate required tools and authentication
  validate_required_tools
  validate_onepassword_auth
  
  # Execute main workflow
  validate_or_generate_ssh_keys
  validate_or_retrieve_password
  download_or_validate_iso
  generate_answer_file
  create_bootable_usb
  
  # Eject USB device
  eject_usb
  
  # Print success message
  print_success_message
}

# Run main function with all arguments
main "$@"
