
resource "aws_instance" "this" {

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  key_name = var.key_name

  iam_instance_profile = var.iam_instance_profile

  user_data = file("${path.module}/user-data.sh")

  root_block_device {

    volume_size = 20

    volume_type = "gp3"

    encrypted = true

    delete_on_termination = true

    tags = merge(
      var.common_tags,
      {
        Name = "${var.instance_name}-root-volume"
      }
    )

  }

  vpc_security_group_ids = [var.security_group_id]

  tags = merge(
    var.common_tags,
    {
      Name = var.instance_name
    }
  )

}

