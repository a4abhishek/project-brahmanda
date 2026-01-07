terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend configuration (uncomment after first successful apply)
  # backend "s3" {
  #   bucket = "brahmanda-terraform-state"
  #   key    = "kshitiz/terraform.tfstate"
  #   region = "us-east-1"
  # }
}
