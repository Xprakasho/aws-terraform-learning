
variable "ami_id" {
  description = "AMI ID for EC2"
  type        = string
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "instance_name" {
  description = "EC2 Name"
  type        = string
}

variable "common_tags" {

  description = "Common tags"

  type = map(string)

}

variable "security_group_id" {

  description = "Security Group ID"

  type = string

}

variable "key_name" {

  description = "EC2 Key Pair Name"

  type = string

}

variable "iam_instance_profile" {

  description = "IAM Instance Profile"

  type = string

}
