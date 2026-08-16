############################################
# VPC
############################################

resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-lab-vpc"
  }

}

############################################
# Public Subnet
############################################

resource "aws_subnet" "public" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-lab-public-subnet"
  }

}

############################################
# Internet Gateway
############################################

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-lab-igw"
  }

}

############################################
# Route Table
############################################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id

  }

}

############################################
# Route Table Association
############################################

resource "aws_route_table_association" "public" {

  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id

}

############################################
# Security Group
############################################

resource "aws_security_group" "ec2_sg" {

  name        = "terraform-lab-sg"
  description = "Security Group for IAM Lab"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-lab-sg"
  }

}