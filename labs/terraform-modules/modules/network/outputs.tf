
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Primary public subnet ID for existing EC2 workloads"
  value       = aws_subnet.public[0].id
}

output "public_subnet_ids" {
  description = "IDs of all public subnets"

  value = [
    for subnet in aws_subnet.public : subnet.id
  ]
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}

output "route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_subnet_ids" {
  description = "IDs of all private subnets"

  value = [
    for subnet in aws_subnet.private : subnet.id
  ]
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"

  value = aws_nat_gateway.main.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"

  value = [
    for route_table in aws_route_table.private : route_table.id
  ]
}
