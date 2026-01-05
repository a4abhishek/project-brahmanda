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
#     [--skip-download]
#

set -euo pipefail

# --- Configuration ---
ISO_BASE_URL="https://enterprise.proxmox.com/iso"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_FILE="${PROJECT_ROOT}/samsara/proxmox/answer.toml"
OUTPUT_FILE="${PROJECT_ROOT}/samsara/proxmox/answer.local.toml"
ISO_DIR="${PROJECT_ROOT}/.cache/iso"

# --- Default Values ---
ISO_VERSION="9.1-1"
SSH_KEY_PATH="${HOME}/.ssh/proxmox-brahmanda.pub"
SKIP_DOWNLOAD=false
ROOT_PASSWORD=""
USB_DEVICE=""

# --- Parse Arguments ---
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
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# --- Validation ---
if [[ -z "$USB_DEVICE" ]]; then
  echo "ERROR: --usb-device is required"
  exit 1
fi

if ! lsblk "$USB_DEVICE" >/dev/null 2>&1; then
  echo "ERROR: USB device $USB_DEVICE not found or inaccessible"
  echo "Available devices:"
  lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT
  exit 1
fi

# Check if it's a disk device (not a partition)
DEVICE_TYPE=$(lsblk -dno TYPE "$USB_DEVICE" 2>/dev/null || echo "unknown")
if [[ "$DEVICE_TYPE" != "disk" ]]; then
  echo "ERROR: $USB_DEVICE is not a disk device (type: $DEVICE_TYPE)"
  echo "Please specify the disk device (e.g., /dev/sdb), not a partition (e.g., /dev/sdb1)"
  exit 1
fi

# --- Step 1: Check/Generate SSH Keys ---
echo "📋 Step 1/5: Validating SSH keys..."

SSH_PRIVATE_KEY="${SSH_KEY_PATH%.pub}"

# Check if keys already exist
if [[ -f "$SSH_KEY_PATH" ]]; then
  echo "✅ SSH public key found: $SSH_KEY_PATH"
  # Verify private key also exists
  if [[ ! -f "$SSH_PRIVATE_KEY" ]]; then
    echo "⚠️  WARNING: Public key exists but private key missing at $SSH_PRIVATE_KEY"
    echo "   You may have authentication issues. Consider regenerating the key pair."
  fi
else
  echo "SSH public key not found at $SSH_KEY_PATH"
  read -p "Generate new Ed25519 key pair? [y/N]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Generating SSH key pair..."
    mkdir -p "$(dirname "$SSH_PRIVATE_KEY")"
    ssh-keygen -t ed25519 -C "proxmox-brahmanda-root" -f "$SSH_PRIVATE_KEY" -N ""
    echo "✅ SSH keys generated:"
    echo "   Private: $SSH_PRIVATE_KEY"
    echo "   Public:  $SSH_KEY_PATH"
  else
    echo "ERROR: SSH key required. Exiting."
    exit 1
  fi
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")

# --- Step 2: Retrieve Root Password ---
echo "📋 Step 2/5: Validating root password..."

if [[ -z "$ROOT_PASSWORD" ]]; then
  echo "Root password not provided. Attempting 1Password lookup..."
  if ! command -v op &> /dev/null; then
    echo "ERROR: 1Password CLI not found. Install or provide --root-password"
    exit 1
  fi
  
  if ! op account get &> /dev/null; then
    echo "ERROR: 1Password CLI not authenticated. Run 'eval \$(op signin)'"
    exit 1
  fi
  
  ROOT_PASSWORD=$(op read "op://Project-Brahmanda/Proxmox Brahmanda Root Password/password")
  if [[ -z "$ROOT_PASSWORD" ]]; then
    echo "ERROR: Failed to retrieve password from 1Password"
    exit 1
  fi
fi

echo "✅ Root password validated (length: ${#ROOT_PASSWORD} chars)"

# --- Step 3: Download ISO ---
ISO_FILENAME="proxmox-ve_${ISO_VERSION}.iso"
ISO_PATH="${ISO_DIR}/${ISO_FILENAME}"

echo "📋 Step 3/5: Preparing Proxmox ISO..."

if [[ "$SKIP_DOWNLOAD" == "true" ]] && [[ -f "$ISO_PATH" ]]; then
  echo "✅ Skipping download (--skip-download). Using existing: $ISO_PATH"
elif [[ -f "$ISO_PATH" ]]; then
  echo "ISO already exists: $ISO_PATH"
  read -p "Re-download? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Using existing ISO"
  else
    rm -f "$ISO_PATH"
  fi
fi

if [[ ! -f "$ISO_PATH" ]]; then
  mkdir -p "$ISO_DIR"
  echo "Downloading ${ISO_FILENAME}..."
  ISO_URL="${ISO_BASE_URL}/${ISO_FILENAME}"
  
  if command -v curl &> /dev/null; then
    if ! curl -# -L -o "$ISO_PATH" "$ISO_URL"; then
      echo "ERROR: Failed to download ISO from $ISO_URL"
      rm -f "$ISO_PATH"
      exit 1
    fi
  elif command -v wget &> /dev/null; then
    if ! wget --progress=bar:force -O "$ISO_PATH" "$ISO_URL"; then
      echo "ERROR: Failed to download ISO from $ISO_URL"
      rm -f "$ISO_PATH"
      exit 1
    fi
  else
    echo "ERROR: Neither curl nor wget found. Cannot download ISO."
    exit 1
  fi
  
  # Verify ISO was downloaded and has reasonable size (>100MB)
  if [[ ! -f "$ISO_PATH" ]]; then
    echo "ERROR: ISO file not found after download"
    exit 1
  fi
  
  ISO_SIZE=$(stat -f%z "$ISO_PATH" 2>/dev/null || stat -c%s "$ISO_PATH" 2>/dev/null || echo "0")
  if [[ "$ISO_SIZE" -lt 104857600 ]]; then
    echo "ERROR: Downloaded ISO appears corrupted (size: $ISO_SIZE bytes, expected >100MB)"
    rm -f "$ISO_PATH"
    exit 1
  fi
  
  echo "✅ ISO downloaded: $ISO_PATH (${ISO_SIZE} bytes)"
fi

# --- Step 4: Generate answer.local.toml ---
echo "📋 Step 4/5: Generating answer.local.toml..."

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "ERROR: Template file not found: $TEMPLATE_FILE"
  exit 1
fi

# Check for dasel (required for TOML editing)
if ! command -v dasel &> /dev/null; then
  echo "ERROR: dasel not found. Required for TOML editing."
  echo "Install via: make init"
  exit 1
fi

# Check if output file already exists and has correct SSH key
if [[ -f "$OUTPUT_FILE" ]] && grep -qF "$SSH_PUBLIC_KEY" "$OUTPUT_FILE" 2>/dev/null; then
  echo "✅ Configuration file already exists with correct SSH key: $OUTPUT_FILE"
  echo "   Regenerating to ensure password is current..."
fi

# Read template and replace placeholders
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Hash password using OpenSSL (available on all Unix systems)
PASSWORD_HASH=$(openssl passwd -6 "$ROOT_PASSWORD")

# Use dasel to set values in TOML (no escaping needed!)
if ! dasel put -f "$OUTPUT_FILE" -r toml -t string -v "$PASSWORD_HASH" '.root_password'; then
  echo "ERROR: Failed to set root_password in answer.local.toml"
  exit 1
fi

if ! dasel put -f "$OUTPUT_FILE" -r toml -t string -v "$SSH_PUBLIC_KEY" '.root_ssh_keys.[0]'; then
  echo "ERROR: Failed to set root_ssh_keys in answer.local.toml"
  exit 1
fi

echo "✅ Configuration generated: $OUTPUT_FILE"
echo "   Root password: [HASHED]"
echo "   SSH public key: ${SSH_PUBLIC_KEY:0:40}..."

# Verify the configuration was written correctly using dasel
if ! dasel select -f "$OUTPUT_FILE" -r toml '.root_password' &>/dev/null || \
   ! dasel select -f "$OUTPUT_FILE" -r toml '.root_ssh_keys.[0]' &>/dev/null; then
  echo "ERROR: Failed to generate answer.local.toml correctly"
  echo "Please check template file: $TEMPLATE_FILE"
  exit 1
fi

# --- Step 5: Create Bootable USB ---
echo "📋 Step 5/5: Creating bootable USB drive..."

if ! command -v proxmox-auto-install-assistant &> /dev/null; then
  echo "ERROR: proxmox-auto-install-assistant not found"
  echo "Install via: make init"
  exit 1
fi

echo "⚠️  WARNING: This will ERASE ALL DATA on $USB_DEVICE"
lsblk "$USB_DEVICE"
read -p "Continue? [y/N]: " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted by user."
  exit 1
fi

echo "Creating bootable installation medium..."
TMP_ISO="/tmp/proxmox-auto-${ISO_VERSION}.iso"

# Unmount any mounted partitions on the USB device
echo "Checking for mounted partitions..."
MOUNTED_PARTS=$(lsblk -no MOUNTPOINT "$USB_DEVICE" 2>/dev/null | grep -v '^$' || true)
if [[ -n "$MOUNTED_PARTS" ]]; then
  echo "Unmounting partitions on $USB_DEVICE..."
  # Get all partitions and unmount them
  for PART in $(lsblk -lno NAME "$USB_DEVICE" | grep -v "^$(basename "$USB_DEVICE")$"); do
    PART_PATH="/dev/$PART"
    if mountpoint -q "$(lsblk -no MOUNTPOINT "$PART_PATH" 2>/dev/null || echo '')"; then
      sudo umount "$PART_PATH" 2>/dev/null || true
    fi
  done
  echo "✅ Partitions unmounted"
fi

if ! sudo proxmox-auto-install-assistant prepare-iso \
  "$ISO_PATH" \
  --fetch-from iso \
  --answer-file "$OUTPUT_FILE" \
  --output-file "$TMP_ISO"; then
  echo "ERROR: Failed to create bootable ISO with proxmox-auto-install-assistant"
  rm -f "$TMP_ISO"
  exit 1
fi

if [[ ! -f "$TMP_ISO" ]]; then
  echo "ERROR: Bootable ISO not created at $TMP_ISO"
  exit 1
fi

echo "Writing ISO to USB device..."
if ! sudo dd if="$TMP_ISO" of="$USB_DEVICE" bs=4M status=progress oflag=sync; then
  echo "ERROR: Failed to write ISO to USB device"
  rm -f "$TMP_ISO"
  exit 1
fi

echo "Syncing filesystems..."
sync

echo "Cleaning up..."
rm -f "$TMP_ISO"

echo ""
echo "✅ SUCCESS: Pratistha complete!"
echo ""
echo "Next Steps:"
echo "  1. Safely eject USB: sudo eject $USB_DEVICE"
echo "  2. Boot ASUS NUC from USB"
echo "  3. Proxmox will install automatically using answer.local.toml"
echo "  4. After installation, access Web UI: https://proxmox.brahmanda.local:8006"
echo "  5. SSH access: ssh root@proxmox.brahmanda.local"
echo ""
