# Persistent Infrastructure
# This module contains resources that should NEVER be destroyed during regular cycles.

# 1Password Provider Configuration
provider "onepassword" {
}

data "onepassword_item" "aws_credentials" {
  vault = "Project-Brahmanda"
  title = "AWS-samsara-iac"
}

data "onepassword_item" "hostinger_credentials" {
  vault = "Project-Brahmanda"
  title = "Hostinger-Parichay-Token"
}

locals {
  aws_creds_fields = flatten([
    for s in data.onepassword_item.aws_credentials.section : s.field
    if s.label == "Security Credentials"
  ])
  
  hostinger_api_token = data.onepassword_item.hostinger_credentials.password
}

provider "aws" {
  region     = var.aws_region
  access_key = one([for f in local.aws_creds_fields : f.value if f.label == "AWS_ACCESS_KEY_ID"])
  secret_key = one([for f in local.aws_creds_fields : f.value if f.label == "AWS_SECRET_ACCESS_KEY"])
  
  default_tags {
    tags = {
      Project   = "Brahmanda"
      ManagedBy = "Terraform"
      Layer     = "Persistence"
    }
  }
}

provider "hostinger" {
  api_token = local.hostinger_api_token
}

resource "aws_lightsail_static_ip" "kshitiz" {
  name = "kshitiz-static-ip"
}

# --- DNS Configuration (Achala) ---

resource "hostinger_dns_record" "root_a" {
  zone  = var.domain_name
  name  = "@"
  type  = "A"
  value = aws_lightsail_static_ip.kshitiz.ip_address
  ttl   = 14400
}

resource "hostinger_dns_record" "vyom_wildcard" {
  zone  = var.domain_name
  name  = "*.vyom"
  type  = "A"
  value = aws_lightsail_static_ip.kshitiz.ip_address
  ttl   = 14400
}
