
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone"
  type        = string
}

variable "instances" {
  description = "EC2 instances to create"

  type = map(object({
    instance_type = string
  }))
}
