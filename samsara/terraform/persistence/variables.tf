# AWS Configuration
variable "aws_region" {
  description = "AWS region for Lightsail instance (Linked to transient infrastructure in samsara/terraform/kshitiz/)"
  type        = string
  default     = "ap-southeast-1" # Singapore
}

variable "domain_name" {
  description = "The root domain name managed by Hostinger"
  type        = string
  default     = "abhishek-kashyap.com"
}
