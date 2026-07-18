
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP"
  value       = aws_instance.this.private_ip
}
