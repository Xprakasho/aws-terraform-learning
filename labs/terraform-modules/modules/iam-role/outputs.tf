output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.this.name
}
