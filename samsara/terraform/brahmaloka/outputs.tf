# Human-friendly outputs for operators
output "runner_name" {
  description = "Brahmaloka Runner VM name"
  value       = proxmox_virtual_environment_vm.brahmaloka_node_1.name
}

output "runner_ip" {
  description = "Brahmaloka Runner IP address"
  value       = proxmox_virtual_environment_vm.brahmaloka_node_1.initialization[0].ip_config[0].ipv4[0].address
}

output "runner_ssh" {
  description = "SSH connection string for runner"
  value       = "ssh ubuntu@${split("/", proxmox_virtual_environment_vm.brahmaloka_node_1.initialization[0].ip_config[0].ipv4[0].address)[0]}"
}

# Ansible Inventory
# Generate Automation Manifest
# This file serves as a clean interface between Terraform and other tools.
resource "local_file" "automation_manifest" {
  content = jsonencode({
    brahmaloka = {
      hosts = [
        {
          name         = proxmox_virtual_environment_vm.brahmaloka_node_1.name
          ansible_host = split("/", proxmox_virtual_environment_vm.brahmaloka_node_1.initialization[0].ip_config[0].ipv4[0].address)[0]
          ansible_user = "ubuntu" # Comes from Prakriti template
          ansible_port = 22       # Default SSH port
        }
      ]
    }
  })
  filename = "${path.module}/manifest.json"
}
