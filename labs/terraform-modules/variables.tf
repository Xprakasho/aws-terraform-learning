
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability Zones for the network"
  type        = list(string)
}

variable "instances" {
  description = "EC2 instances to create"

  type = map(object({
    instance_type = string
  }))
}

variable "key_name" {

  description = "AWS Key Pair Name"

  type = string

}

variable "public_key_path" {

  description = "Path to SSH Public Key"

  type = string

}

variable "role_name" {

  description = "IAM Role Name"

  type = string

}

