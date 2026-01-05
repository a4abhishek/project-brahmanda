#!/usr/bin/env bash
# mukti-usb.sh - Mukti (Liberation) of USB Drive
#
# Safely reclaims a USB drive after Pratistha (OS Consecration) by formatting it
# for general use. Removes bootable installation media and returns USB to clean state.
#
# Philosophy: Following the "Weapon of Detachment" principle, this script liberates
# the USB from its sacred installation purpose, allowing it to be used freely again.
#
# ⚠️  WARNING: This will permanently erase ALL data on the USB device
#
# Usage:
#   ./mukti-usb.sh --usb-device /dev/sdX [--format exfat] [--label BRAHMANDA] [--force]
#
# Parameters:
#   --usb-device    : Target USB device (required, e.g., /dev/sdb)
#   --format        : Filesystem format (default: exfat, options: exfat, fat32, ext4, ntfs)
#   --label         : Volume label (default: BRAHMANDA)
#   --force         : Skip confirmation prompt (use for automation)
#
# Examples:
#   ./mukti-usb.sh --usb-device /dev/sdb
#   ./mukti-usb.sh --usb-device /dev/sdb --format fat32 --label "USB_DRIVE"
#   ./mukti-usb.sh --usb-device /dev/sdb --force

set -euo pipefail

# --- Colors and Formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Default Configuration ---
USB_DEVICE=""
FORMAT="exfat"
LABEL="BRAHMANDA"
FORCE=false

# --- Helper Functions ---
log_info() {
    echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $*" >&2
}

log_step() {
    echo -e "${CYAN}==>${NC} ${BOLD}$*${NC}"
}

# --- Parse Command-Line Arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --usb-device)
            USB_DEVICE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --label)
            LABEL="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            log_error "Unknown parameter: $1"
            echo "Usage: $0 --usb-device /dev/sdX [--format exfat] [--label BRAHMANDA] [--force]"
            exit 1
            ;;
    esac
done

# --- Validation ---
if [[ -z "$USB_DEVICE" ]]; then
    log_error "USB_DEVICE parameter is required"
    echo "Usage: $0 --usb-device /dev/sdX [--format exfat] [--label BRAHMANDA] [--force]"
    exit 1
fi

# Validate format choice
case "$FORMAT" in
    exfat|fat32|ext4|ntfs)
        ;;
    *)
        log_error "Invalid format: $FORMAT"
        echo "Supported formats: exfat, fat32, ext4, ntfs"
        exit 1
        ;;
esac

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# --- Safety Checks ---
log_step "Running safety checks on $USB_DEVICE..."

# Check if device exists
if [[ ! -b "$USB_DEVICE" ]]; then
    log_error "Device $USB_DEVICE does not exist or is not a block device"
    exit 1
fi
log_info "✓ Device exists"

# Check if device is removable (RM flag in lsblk)
REMOVABLE=$(lsblk -no RM "$USB_DEVICE" 2>/dev/null | head -n1 | tr -d '[:space:]')
if [[ "$REMOVABLE" != "1" ]]; then
    log_error "Device $USB_DEVICE is NOT removable (RM=$REMOVABLE)"
    log_error "This safety check prevents formatting internal drives"
    log_error "If you're certain this is a USB drive, check 'lsblk -o NAME,RM,SIZE,TYPE,MOUNTPOINT'"
    exit 1
fi
log_info "✓ Device is removable (RM=1)"

# Get device info for confirmation
DEVICE_SIZE=$(lsblk -no SIZE "$USB_DEVICE" | head -n1 | tr -d '[:space:]')
DEVICE_MODEL=$(lsblk -no MODEL "$USB_DEVICE" 2>/dev/null | head -n1 | tr -d '[:space:]' || echo "Unknown")
log_info "✓ Device size: $DEVICE_SIZE"
log_info "✓ Device model: $DEVICE_MODEL"

# Check if device is mounted
MOUNTED_PARTITIONS=$(lsblk -no MOUNTPOINT "$USB_DEVICE" 2>/dev/null | grep -v '^$' || true)
if [[ -n "$MOUNTED_PARTITIONS" ]]; then
    log_warning "Device has mounted partitions:"
    echo "$MOUNTED_PARTITIONS"
    log_info "Unmounting all partitions..."
    
    # Unmount all partitions
    for PARTITION in $(lsblk -lno NAME "$USB_DEVICE" | tail -n +2); do
        MOUNT_POINT=$(lsblk -no MOUNTPOINT "/dev/$PARTITION" 2>/dev/null || true)
        if [[ -n "$MOUNT_POINT" ]]; then
            log_info "Unmounting /dev/$PARTITION from $MOUNT_POINT"
            umount "/dev/$PARTITION" || {
                log_error "Failed to unmount /dev/$PARTITION"
                exit 1
            }
        fi
    done
    log_info "✓ All partitions unmounted"
fi

# --- Confirmation ---
if [[ "$FORCE" != "true" ]]; then
    echo ""
    echo -e "${BOLD}${YELLOW}⚠️  WARNING: DESTRUCTIVE OPERATION${NC}"
    echo -e "${YELLOW}This will permanently erase all data on:${NC}"
    echo -e "  Device: ${BOLD}$USB_DEVICE${NC}"
    echo -e "  Size:   ${BOLD}$DEVICE_SIZE${NC}"
    echo -e "  Model:  ${BOLD}$DEVICE_MODEL${NC}"
    echo ""
    echo -e "Format: ${BOLD}$FORMAT${NC}"
    echo -e "Label:  ${BOLD}$LABEL${NC}"
    echo ""
    read -p "Type 'YES' to confirm: " CONFIRM
    
    if [[ "$CONFIRM" != "YES" ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
fi

# --- Validate and Sanitize Label ---
# Different filesystems have different label length limits:
# - exFAT: 11 characters (ASCII) / 15 characters (UTF-16)
# - FAT32: 11 characters
# - NTFS: 32 characters
# - ext4: 16 characters

ORIGINAL_LABEL="$LABEL"
case "$FORMAT" in
    exfat)
        MAX_LABEL_LENGTH=11
        ;;
    fat32)
        MAX_LABEL_LENGTH=11
        ;;
    ntfs)
        MAX_LABEL_LENGTH=32
        ;;
    ext4)
        MAX_LABEL_LENGTH=16
        ;;
esac

# Truncate label if necessary
if [[ ${#LABEL} -gt $MAX_LABEL_LENGTH ]]; then
    LABEL="${LABEL:0:$MAX_LABEL_LENGTH}"
    log_warning "Label truncated from '$ORIGINAL_LABEL' to '$LABEL' (max $MAX_LABEL_LENGTH chars for $FORMAT)"
fi

# --- Format USB Drive ---
log_step "Liberating USB drive..."

# Wipe existing filesystem signatures
log_info "Wiping filesystem signatures..."
wipefs --all --force "$USB_DEVICE" >/dev/null 2>&1 || true

# Create new partition table (GPT for modern systems)
log_info "Creating new GPT partition table..."
parted -s "$USB_DEVICE" mklabel gpt

# Create single partition spanning entire disk
log_info "Creating primary partition..."
parted -s "$USB_DEVICE" mkpart primary 0% 100%

# Wait for kernel to update partition table
sync
sleep 2

# Determine partition device name
# For /dev/sdb, partition is /dev/sdb1
# For /dev/nvme0n1, partition is /dev/nvme0n1p1
if [[ "$USB_DEVICE" =~ nvme ]]; then
    PARTITION="${USB_DEVICE}p1"
else
    PARTITION="${USB_DEVICE}1"
fi

# Wait for partition to be available
for i in {1..10}; do
    if [[ -b "$PARTITION" ]]; then
        break
    fi
    sleep 1
done

if [[ ! -b "$PARTITION" ]]; then
    log_error "Partition $PARTITION not found after creation"
    exit 1
fi

# Format partition based on chosen filesystem
log_info "Formatting partition as $FORMAT..."
case "$FORMAT" in
    exfat)
        # Check if exfat-fuse/exfatprogs is installed
        if ! command -v mkfs.exfat &> /dev/null; then
            log_error "mkfs.exfat not found. Install exfatprogs: sudo apt install exfatprogs"
            exit 1
        fi
        mkfs.exfat -n "$LABEL" "$PARTITION"
        ;;
    fat32)
        mkfs.vfat -F 32 -n "$LABEL" "$PARTITION"
        ;;
    ext4)
        mkfs.ext4 -F -L "$LABEL" "$PARTITION"
        ;;
    ntfs)
        # Check if ntfs-3g is installed
        if ! command -v mkfs.ntfs &> /dev/null; then
            log_error "mkfs.ntfs not found. Install ntfs-3g: sudo apt install ntfs-3g"
            exit 1
        fi
        mkfs.ntfs -f -L "$LABEL" "$PARTITION"
        ;;
esac

# Sync to ensure all writes are flushed
sync

log_success "USB drive liberated successfully"
echo ""

# --- Verification ---
log_step "Verification:"
echo ""
echo "Device Information:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$USB_DEVICE"
echo ""

log_info "Filesystem details:"
blkid "$PARTITION" || true

echo ""
log_success "Mukti (Liberation) complete"
log_info "USB drive is ready for general use"
log_info "You can safely remove the USB drive now (or run: sudo eject $USB_DEVICE)"
