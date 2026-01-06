# AWS Configuration
variable "aws_region" {
  description = "AWS region for Lightsail instance"
  type        = string
  default     = "us-east-1"
}

variable "instance_bundle_id" {
  description = "Lightsail bundle ID (size/price tier)"
  type        = string
  default     = "nano_3_0" # $3.50/month - 512MB RAM, 1 vCPU, 20GB SSD
  
  # Available bundles:
  # nano_3_0   - $3.50/month  - 512MB RAM, 1 vCPU, 20GB SSD
  # micro_3_0  - $5.00/month  - 1GB RAM, 1 vCPU, 40GB SSD
  # small_3_0  - $10.00/month - 2GB RAM, 1 vCPU, 60GB SSD
  # medium_3_0 - $20.00/month - 4GB RAM, 2 vCPU, 80GB SSD
}

# Nebula Configuration
variable "nebula_version" {
  description = "Nebula version to install"
  type        = string
  default     = "1.9.5"
}

variable "nebula_lighthouse_port" {
  description = "UDP port for Nebula Lighthouse"
  type        = number
  default     = 4242
}

# Security Configuration
variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into Lighthouse"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Open to world - restrict to your IP in production
  
  # To restrict to your home IP (recommended):
  # default = ["YOUR_HOME_IP/32"]
}

# Nebula Network Configuration
variable "nebula_network_cidr" {
  description = "Internal Nebula mesh network CIDR"
  type        = string
  default     = "10.42.0.0/16"
}

variable "lighthouse_nebula_ip" {
  description = "Lighthouse IP within Nebula mesh"
  type        = string
  default     = "10.42.0.1/16"
}
