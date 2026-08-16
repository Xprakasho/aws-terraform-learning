
output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "internet_gateway_id" {
  value = module.network.internet_gateway_id
}

output "route_table_id" {
  value = module.network.route_table_id
}

output "instance_id" {
  value = {
    for k, v in module.compute :
    k => v.instance_id
  }
}

output "public_ip" {
  value = {
    for k, v in module.compute :
    k => v.public_ip
  }
}

output "private_ip" {
  value = {
    for k, v in module.compute :
    k => v.private_ip
  }
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = module.network.nat_gateway_id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = module.network.private_route_table_ids
}
