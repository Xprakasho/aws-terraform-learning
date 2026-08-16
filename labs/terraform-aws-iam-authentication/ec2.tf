resource "aws_instance" "iam_lab" {

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  key_name = var.key_name

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data_base64 = filebase64("${path.module}/user-data.sh")

  tags = {
    Name = "terraform-iam-lab"
  }

}