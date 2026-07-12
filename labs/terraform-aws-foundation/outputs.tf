
output "ubuntu_ami_id" {

  description = "Latest Ubuntu AMI"

  value = data.aws_ami.ubuntu.id

}
/*
output "instance_public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.lab_ec2[*].public_ip
}

output "instance_private_ip" {
  description = "Private IP of EC2"
  value       = aws_instance.lab_ec2[*].private_ip
}
*/

output "instance_public_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.public_ip
  }
}

output "instance_private_ip" {
  value = {
    for name, instance in aws_instance.lab_ec2 :
    name => instance.private_ip
  }
}
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}
