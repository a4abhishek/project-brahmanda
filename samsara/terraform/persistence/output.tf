# Kshitiz Public IP Information
output "static_ip" {
  value = aws_lightsail_static_ip.kshitiz.ip_address
}

output "static_ip_name" {
  value = aws_lightsail_static_ip.kshitiz.name
}
