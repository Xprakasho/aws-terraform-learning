
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI Profile"
  type        = string
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
}

/*
variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
}
*/

variable "instances" {
  description = "EC2 instance configurations"

  type = map(object({
    instance_type = string
    monitoring    = bool
    environment   = string
  }))
}

variable "ingress_rules" {
  description = "Ingress rules for the public security group"

  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

