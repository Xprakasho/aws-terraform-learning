resource "aws_autoscaling_group" "web" {
  name             = "terraform-web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.public[*].id

  target_group_arns = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-web"
    propagate_at_launch = true
  }
}