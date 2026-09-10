resource "aws_launch_template" "web" {

  user_data = base64encode(<<-EOF
  #!/bin/bash
  dnf install -y nginx
  systemctl enable nginx
  systemctl start nginx
EOF
  )
  name_prefix   = "terraform-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-launch-template"
    }
  }
}

