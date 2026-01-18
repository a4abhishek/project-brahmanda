terraform {
  required_version = ">= 1.9.0"

  required_providers {
    onepassword = {
      source = "1Password/onepassword"
    }
    proxmox = {
      source = "Telmate/proxmox"
    }
  }

  # Backend configuration (uncomment after first successful apply)
  # backend "s3" {
  #   bucket = "brahmanda-terraform-state"
  #   key    = "vyom/terraform.tfstate"
  #   region = "ap-southeast-1a"
  # }
}
