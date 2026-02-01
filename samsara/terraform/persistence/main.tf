# Persistent Infrastructure
# This module contains resources that should NEVER be destroyed during regular cycles.

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    onepassword = {
      source = "1Password/onepassword"
    }
  }

  backend "s3" {
    bucket                      = "brahmanda-state"
    key                         = "persistence/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

# 1Password Provider Configuration
provider "onepassword" {
}

data "onepassword_item" "aws_credentials" {
  vault = "Project-Brahmanda"
  title = "AWS-samsara-iac"
}

locals {
  aws_creds_fields = flatten([
    for s in data.onepassword_item.aws_credentials.section : s.field
    if s.label == "Security Credentials"
  ])
}

provider "aws" {
  region     = "ap-southeast-1" # Singapore
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

resource "aws_lightsail_static_ip" "kshitiz" {
  name = "kshitiz-static-ip"
}

output "static_ip" {
  value = aws_lightsail_static_ip.kshitiz.ip_address
}

output "static_ip_name" {
  value = aws_lightsail_static_ip.kshitiz.name
}
