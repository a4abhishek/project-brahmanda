# Instance Information
output "instance_name" {
  description = "Lightsail instance name"
  value       = aws_lightsail_instance.lighthouse.name
}

output "instance_id" {
  description = "Lightsail instance ID"
  value       = aws_lightsail_instance.lighthouse.id
}

# Network Information
output "public_ip" {
  description = "Public IP address (static)"
  value       = aws_lightsail_static_ip.lighthouse.ip_address
}

output "private_ip" {
  description = "Private IP address within AWS"
  value       = aws_lightsail_instance.lighthouse.private_ip_address
}

output "nebula_lighthouse_ip" {
  description = "Lighthouse IP within Nebula mesh network"
  value       = var.lighthouse_nebula_ip
}

# Access Information
output "ssh_connection" {
  description = "SSH connection string"
  value       = "ssh ubuntu@${aws_lightsail_static_ip.lighthouse.ip_address}"
}

output "nebula_lighthouse_endpoint" {
  description = "Nebula Lighthouse endpoint for client configuration"
  value       = "${aws_lightsail_static_ip.lighthouse.ip_address}:${var.nebula_lighthouse_port}"
}

# Ansible Inventory
output "ansible_inventory" {
  description = "Ansible inventory entry for this host"
  value = yamlencode({
    all = {
      hosts = {
        kshitiz-lighthouse = {
          ansible_host = aws_lightsail_static_ip.lighthouse.ip_address
          ansible_user = "ubuntu"
          nebula_ip    = var.lighthouse_nebula_ip
          role         = "lighthouse"
        }
      }
    }
  })
}
