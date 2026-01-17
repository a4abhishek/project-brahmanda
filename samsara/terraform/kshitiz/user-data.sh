#!/bin/bash
set -euo pipefail

# User data script for Lightsail instance initial setup
# This runs once when the instance is first created

echo "=== Kshitiz Lighthouse Initial Setup ==="
echo "Starting at: $(date)"

# Update system packages
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install essential packages
apt-get install -y \
  curl \
  wget \
  vim \
  htop \
  net-tools \
  ufw \
  unzip

# Configure UFW (Uncomplicated Firewall)
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH
ufw allow 4242/udp    # Nebula
ufw allow 443/tcp     # HTTPS
ufw reload

echo "=== Initial setup complete ==="
echo "Ready for Ansible configuration"
echo "Completed at: $(date)"
