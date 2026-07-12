
moved {
  from = aws_instance.lab_ec2[0]
  to   = aws_instance.lab_ec2["web"]
}

moved {
  from = aws_instance.lab_ec2[1]
  to   = aws_instance.lab_ec2["app"]
}
