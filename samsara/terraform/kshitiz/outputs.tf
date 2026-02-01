# Instance Information
output "instance_name" {
  description = "Lightsail instance name"
  value       = aws_lightsail_instance.kshitiz.name
}

output "instance_id" {
  description = "Lightsail instance ID"
  value       = aws_lightsail_instance.kshitiz.id
}

# Network Information
output "public_ip" {
  description = "Public IP address (static)"
  value       = data.terraform_remote_state.persistence.outputs.static_ip
}

output "private_ip" {
  description = "Private IP address within AWS"
  value       = aws_lightsail_instance.kshitiz.private_ip_address
}

output "nebula_lighthouse_ip" {
  description = "Lighthouse IP within Nebula mesh network"
  value       = var.lighthouse_nebula_ip
}

# Access Information
output "ssh_connection" {
  description = "SSH connection string"
  value       = "ssh ubuntu@${data.terraform_remote_state.persistence.outputs.static_ip}"
}

output "nebula_lighthouse_endpoint" {
  description = "Nebula Lighthouse endpoint for client configuration"
  value       = "${data.terraform_remote_state.persistence.outputs.static_ip}:${var.nebula_lighthouse_port}"
}

# Ansible Inventory
# Generate Automation Manifest
# This file serves as a clean interface between Terraform and other tools.
resource "local_file" "automation_manifest" {
  content = jsonencode({
    kshitiz = {
      hosts = [
        {
          name         = aws_lightsail_instance.kshitiz.id
          ansible_host = data.terraform_remote_state.persistence.outputs.static_ip
          ansible_user = "ubuntu"
          ansible_port = var.ssh_port
        }
      ]
    }
  })
  filename = "${path.module}/manifest.json"
}
