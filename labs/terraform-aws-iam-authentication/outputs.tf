output "instance_id" {
  value = aws_instance.iam_lab.id
}

output "public_ip" {
  value = aws_instance.iam_lab.public_ip
}

output "iam_role" {
  value = aws_iam_role.ec2_role.name
}

output "instance_profile" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}