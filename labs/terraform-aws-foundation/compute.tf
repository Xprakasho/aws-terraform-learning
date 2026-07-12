
resource "aws_instance" "lab_ec2" {

  #count = var.instance_count

  for_each = var.instances

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type
  monitoring    = each.value.monitoring

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.public_sg.id
  ]

  key_name = "my-key1"

  tags = {
    Name        = "Terraform-EC2-${each.key}"
    Environment = each.value.environment
  }

}
