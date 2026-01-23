terraform {
  required_version = ">= 1.9.0"

  required_providers {
    onepassword = {
      source = "1Password/onepassword"
    }
    proxmox = {
      source = "bpg/proxmox"
    }
  }

  backend "s3" {
    bucket                      = "brahmanda-state"
    key                         = "vyom/terraform.tfstate"
    region                      = "auto" # R2 ignores region, but Terraform requires a value
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
