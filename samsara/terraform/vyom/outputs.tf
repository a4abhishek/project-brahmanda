# Human-friendly outputs for operators
output "control_plane_name" {
  description = "K3s control plane VM name"
  value       = proxmox_virtual_environment_vm.control_plane.name
}

output "control_plane_ip" {
  description = "K3s control plane IP address"
  value       = proxmox_virtual_environment_vm.control_plane.initialization[0].ip_config[0].ipv4[0].address
}

output "control_plane_ssh" {
  description = "SSH connection string for control plane"
  value       = "ssh ubuntu@${split("/", proxmox_virtual_environment_vm.control_plane.initialization[0].ip_config[0].ipv4[0].address)[0]}"
}

output "worker_names" {
  description = "K3s worker VM names"
  value       = [for w in proxmox_virtual_environment_vm.worker : w.name]
}

output "worker_ips" {
  description = "K3s worker IP addresses"
  value       = [for w in proxmox_virtual_environment_vm.worker : w.initialization[0].ip_config[0].ipv4[0].address]
}

output "worker_ssh" {
  description = "SSH connection strings for workers"
  value       = [for w in proxmox_virtual_environment_vm.worker : "ssh ubuntu@${split("/", w.initialization[0].ip_config[0].ipv4[0].address)[0]}"]
}

# Build worker hosts list for Ansible inventory
locals {
  k3s_worker_hosts = [
    for w in proxmox_virtual_environment_vm.worker : {
      name         = w.name
      ansible_host = split("/", w.initialization[0].ip_config[0].ipv4[0].address)[0]
      ansible_user = "ubuntu"
      ansible_port = 22
    }
  ]
}

# Ansible Inventory
# Generate Automation Manifest
# This file serves as a clean interface between Terraform and other tools.
resource "local_file" "automation_manifest" {
  content = jsonencode({
    kshitiz = {
      k3s_master = {
        hosts = [
          {
            name         = proxmox_virtual_environment_vm.control_plane.name
            ansible_host = split("/", proxmox_virtual_environment_vm.control_plane.initialization[0].ip_config[0].ipv4[0].address)[0]
            ansible_user = "ubuntu" # Comes from Prakriti template
            ansible_port = 22       # Default SSH port
          }
        ]
      }

      k3s_worker = {
        hosts = local.k3s_worker_hosts
      }
    }
  })
  filename = "${path.module}/manifest.json"
}
