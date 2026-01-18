locals {
  # Define the URL regex pattern, which can be reused in multiple variable validations
  url_regex = "^http[s]?://([a-zA-Z0-9.-]+|([0-9]{1,3}\\.){3}[0-9]{1,3})(:[0-9]{1,5})?(/.*)?$"
}

variable "proxmox_endpoint" {
  description = "The endpoint where proxmox server listens"
  type        = string
  default     = "https://192.168.68.200:8006"

  validation {
    condition     = can(regex(local.url_regex, var.proxmox_endpoint))
    error_message = "The proxmox_endpoint must be a valid HTTPS URL."
  }

  validation {
    condition = startswith(var.proxmox_endpoint, "https://")
    error_message = "The proxmox_endpoint must start with 'https://'."
  }
}

variable "proxmox_node_1" {
  description = "The First Proxmox node name where resources will be created"
  type        = string
  default     = "vyom"
}

variable "proxmox_iso" {
  description = "The ISO image to be used for Proxmox VM creation"
  type        = string
  default     = "local:iso/debian-11.0.0-amd64-netinst.iso"
}
