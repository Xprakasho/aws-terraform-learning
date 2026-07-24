
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
