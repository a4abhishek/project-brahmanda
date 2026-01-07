# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  # Credentials loaded from environment variables or 1Password
  # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

  default_tags {
    tags = {
      Project   = "Brahmanda"
      ManagedBy = "Terraform"
      Layer     = "Kshitiz"
    }
  }
}

# 1. The Lighthouse Instance
# We use the literal blueprint_id "ubuntu_24_04"
resource "aws_lightsail_instance" "kshitiz" {
  name              = "kshitiz-lighthouse"
  availability_zone = "${var.aws_region}a"
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = var.instance_bundle_id

  # User data for initial Nebula bootstrap
  user_data = templatefile("${path.module}/user-data.sh", {
    nebula_version = var.nebula_version
  })

  tags = {
    Name        = "kshitiz-lighthouse"
    Role        = "Nebula-Lighthouse"
    Description = "Edge gateway and Nebula mesh coordinator"
    Project     = "Brahmanda"
    Layer       = "Kshitiz"
    ManagedBy   = "Terraform"
  }
}

# 2. Static IP for Lighthouse
resource "aws_lightsail_static_ip" "kshitiz" {
  name = "kshitiz-static-ip"
}

# Attach static IP to instance
resource "aws_lightsail_static_ip_attachment" "kshitiz_attach" {
  static_ip_name = aws_lightsail_static_ip.kshitiz.name
  instance_name  = aws_lightsail_instance.kshitiz.name
}

# 3. Firewall rules for Lighthouse
resource "aws_lightsail_instance_public_ports" "firewall" {
  instance_name = aws_lightsail_instance.kshitiz.name

  # SSH: Secure management
  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidrs     = var.ssh_allowed_cidrs
  }

  # Nebula Lighthouse port (UDP)
  port_info {
    protocol  = "udp"
    from_port = var.nebula_lighthouse_port
    to_port   = var.nebula_lighthouse_port
    cidrs     = ["0.0.0.0/0"] # Lighthouse needs to be accessible globally
  }

  # HTTPS for future web services (optional)
  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
    cidrs     = ["0.0.0.0/0"]
  }
}
