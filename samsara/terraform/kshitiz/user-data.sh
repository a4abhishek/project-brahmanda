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

# Download Nebula
NEBULA_VERSION="${nebula_version}"
NEBULA_URL="https://github.com/slackhq/nebula/releases/download/v$${NEBULA_VERSION}/nebula-linux-amd64.tar.gz"

echo "Downloading Nebula v$${NEBULA_VERSION}..."
cd /tmp
wget -q "$${NEBULA_URL}" -O nebula.tar.gz
tar -xzf nebula.tar.gz

# Install Nebula binaries
mv nebula /usr/local/bin/
mv nebula-cert /usr/local/bin/
chmod +x /usr/local/bin/nebula
chmod +x /usr/local/bin/nebula-cert

# Create Nebula directories
mkdir -p /etc/nebula
mkdir -p /var/log/nebula

# Create placeholder config (will be replaced by Ansible)
cat > /etc/nebula/config.yml << 'EOF'
# Placeholder Nebula config - will be configured by Ansible
# Do not edit manually
pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/lighthouse.crt
  key: /etc/nebula/lighthouse.key

lighthouse:
  am_lighthouse: true

listen:
  host: 0.0.0.0
  port: 4242

punchy:
  punch: true

tun:
  disabled: false
  dev: nebula1
  mtu: 1300

logging:
  level: info
  format: text
EOF

echo "=== Initial setup complete ==="
echo "Nebula $${NEBULA_VERSION} installed"
echo "Ready for Ansible configuration"
echo "Completed at: $(date)"
