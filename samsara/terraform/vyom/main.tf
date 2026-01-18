# 1Password Provider Configuration
provider "onepassword" {
  # We'll use OP_SERVICE_ACCOUNT_TOKEN environment variable for authentication
  # This will ensure accessability of 1Password secrets for Terraform as well as op CLI.
}

data "onepassword_item" "proxmox_credentials" {
  vault = "Project-Brahmanda"
  title = "Proxmox Brahmanda Root Password"
}

# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url = "${var.proxmox_endpoint}/api2/json"
  pm_user    = data.onepassword_item.proxmox_credentials.username.value
  pm_password = data.onepassword_item.proxmox_credentials.password.value
  pm_tls_insecure = true
}
