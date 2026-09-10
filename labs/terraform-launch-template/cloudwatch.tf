resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "terraform-web-asg-cpu-high"
  alarm_description   = "Alarm when ASG average CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  period             = 60
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  statistic          = "Average"

  threshold = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "terraform-web-alb-unhealthy"
  alarm_description   = "Alarm when ALB has unhealthy targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 2
  period             = 60

  metric_name = "UnHealthyHostCount"
  namespace   = "AWS/ApplicationELB"
  statistic   = "Average"

  threshold = 1

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.web.arn_suffix
  }

  treat_missing_data = "notBreaching"
}