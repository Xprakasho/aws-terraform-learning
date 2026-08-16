
resource "aws_vpc" "main" {

  cidr_block = var.vpc_cidr

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-VPC"
    }
  )

}

resource "aws_subnet" "public" {

  for_each = {
    for index, cidr in var.public_subnet_cidrs :
    index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  vpc_id = aws_vpc.main.id

  cidr_block = each.value.cidr

  availability_zone = each.value.az

  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Public-Subnet-${each.value.az}"
    }
  )

}

resource "aws_subnet" "private" {

  for_each = {
    for index, cidr in var.private_subnet_cidrs :
    index => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  vpc_id = aws_vpc.main.id

  cidr_block = each.value.cidr

  availability_zone = each.value.az

  map_public_ip_on_launch = false

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Private-Subnet-${each.value.az}"
    }
  )

}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-IGW"
    }
  )

}

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Public-RT"
    }
  )

}

resource "aws_route_table" "private" {

  for_each = {
    for index, az in var.availability_zones :
    index => az
  }

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-Private-RT-${each.value}"
    }
  )

}

resource "aws_route_table_association" "public" {

  for_each = aws_subnet.public

  subnet_id = each.value.id

  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "private" {

  for_each = aws_subnet.private

  subnet_id = each.value.id

  route_table_id = aws_route_table.private[each.key].id

}

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-NAT-EIP"
    }
  )

}

resource "aws_nat_gateway" "main" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "Terraform-Module-NAT-Gateway"
    }
  )

}

resource "aws_route" "private_nat" {

  for_each = aws_route_table.private

  route_table_id = each.value.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.main.id

}
