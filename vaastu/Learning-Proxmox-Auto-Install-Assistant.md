# Learning: Proxmox Auto-Install Assistant

## What

CLI tool from Proxmox for creating automated, unattended installation media. Embeds an answer file into a Proxmox ISO to enable hands-free bare-metal installations.

## Installation

```bash
apt install proxmox-auto-install-assistant
```

**Alternate method (without Proxmox repo configured):**
```bash
wget http://download.proxmox.com/debian/pve/dists/bookworm/pvetest/binary-amd64/proxmox-auto-install-assistant_8.4.6_amd64.deb
sudo dpkg -i proxmox-auto-install-assistant_8.4.6_amd64.deb
```

**System Requirements:**
- glibc 2.36+ (Debian 12 Bookworm / Ubuntu 24.04+)
- **xorriso** (CRITICAL - not a declared dependency, must install manually)

### Missing Dependency

The `.deb` package does **not** declare `xorriso` as a dependency, but it's required:

```bash
sudo apt-get install -y xorriso
```

**Failure without xorriso:**
```
Error: Could not find the 'xorriso' binary. Please install it.
```

## Usage

### Basic Command

```bash
proxmox-auto-install-assistant prepare-iso \
  /path/to/proxmox-ve_9.1-1.iso \
  --fetch-from iso \
  --answer-file answer.toml \
  --output /tmp/proxmox-auto.iso
```

**Important:** The argument is `--output`, NOT `--output-file` (some documentation examples are incorrect).

### Answer File Format (TOML)

```toml
[global]
keyboard = "en-us"
country = "us"
fqdn = "hostname.domain.local"
mailto = "admin@domain.local"
timezone = "America/New_York"
root_password = "$6$rounds=656000$..."  # Must be SHA-512 hashed
root_ssh_keys = ["ssh-ed25519 AAAA..."]

[network]
source = "from-dhcp"  # or "from-answer" for static

# For static network, add filter as subsection:
[network.filter]
SUBSYSTEM = "net"  # Match network devices

[disk-setup]
filesystem = "ext4"  # or "xfs", "zfs", "btrfs"
disk_list = ["sda"]
```

### Password Hashing

Plaintext passwords will **not** work. Must use SHA-512:

```bash
openssl passwd -6 "your-password"
```

### Writing to USB

```bash
# Use disk device (/dev/sdX), not partition (/dev/sdX1)
sudo dd if=/tmp/proxmox-auto.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Gotchas

### 1. xorriso Not Auto-Installed

The package doesn't declare it as a dependency. ISO creation will fail without it.

### 2. CLI Argument Name

Use `--output`, not `--output-file` despite what some examples show.

### 3. glibc Version

Requires glibc 2.36+. Will not work on older distros (Debian 11, Ubuntu 22.04).

### 4. Password Must Be Hashed

Answer file requires SHA-512 hashed passwords (`openssl passwd -6`). Plaintext causes silent installation failure.

### 5. Device vs Partition

`dd` target must be disk device (`/dev/sdX`), not partition (`/dev/sdX1`). Verify with:
```bash
lsblk -dno TYPE /dev/sdX  # Must output: disk
```

### 6. Mounted Partitions

Unmount all partitions on target device before `dd`:
```bash
sudo umount /dev/sdX* 2>/dev/null || true
```

### 7. TOML Array Syntax

SSH keys must be an array, even for single key:
```toml
root_ssh_keys = ["key1"]  # Correct
root_ssh_keys = "key1"    # Wrong
```

### 8. Filter Format

Filters must be TOML subsections, not strings:
```toml
# WRONG
filter = ".*"

# CORRECT
[network.filter]
SUBSYSTEM = "net"

[disk-setup.filter]
ID_MODEL = "Samsung*"
```

## References

- [Assistant Tool Documentation](https://pve.proxmox.com/wiki/Automated_Installation#Assistant_Tool)
- [Proxmox Automated Installation Wiki](https://pve.proxmox.com/wiki/Automated_Installation)
- [Answer File Format](https://pve.proxmox.com/wiki/Automated_Installation#Answer_File_Format)
- [Tool Source](http://git.proxmox.com/?p=pve-installer.git)

---

**Tested:** Proxmox VE 9.1-1, assistant 8.4.6, Debian 12 / Ubuntu 24.04
