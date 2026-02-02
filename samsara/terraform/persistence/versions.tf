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
    hostinger = {
      source = "hostinger/hostinger"
      version = "0.1.22"
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
