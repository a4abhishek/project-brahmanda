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

# Data source: Latest Ubuntu 24.04 LTS blueprint for Lightsail
data "aws_lightsail_blueprint" "ubuntu" {
  type = "os"

  # Filter for Ubuntu 24.04 LTS
  filter {
    name   = "name"
    values = ["ubuntu_24_04"]
  }
}

# Data source: Available Lightsail bundles
data "aws_lightsail_bundles" "available" {
  type = "instance"
}

# Lightsail Instance - Nebula Lighthouse
resource "aws_lightsail_instance" "lighthouse" {
  name              = "kshitiz-lighthouse"
  availability_zone = "${var.aws_region}a"
  blueprint_id      = data.aws_lightsail_blueprint.ubuntu.id
  bundle_id         = var.instance_bundle_id

  # User data script - initial setup
  user_data = templatefile("${path.module}/user-data.sh", {
    nebula_version = var.nebula_version
  })

  tags = {
    Name        = "kshitiz-lighthouse"
    Role        = "Nebula-Lighthouse"
    Description = "Edge gateway and Nebula mesh coordinator"
  }
}

# Static IP for Lighthouse
resource "aws_lightsail_static_ip" "lighthouse" {
  name = "kshitiz-lighthouse-ip"
}

# Attach static IP to instance
resource "aws_lightsail_static_ip_attachment" "lighthouse" {
  static_ip_name = aws_lightsail_static_ip.lighthouse.name
  instance_name  = aws_lightsail_instance.lighthouse.name
}

# Firewall rules for Lighthouse
resource "aws_lightsail_instance_public_ports" "lighthouse" {
  instance_name = aws_lightsail_instance.lighthouse.name

  # SSH access
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
