
module "network" {

  source = "./modules/network"

  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone

  common_tags = local.common_tags

}

module "security_group" {

  source = "./modules/security-group"

  vpc_id = module.network.vpc_id

  security_group_name = "terraform-module-sg"

  common_tags = local.common_tags

}

module "compute" {

  for_each = var.instances

  source = "./modules/compute"

  ami_id        = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type
  subnet_id     = module.network.subnet_id
  instance_name = "${local.project_name}-${each.key}"

  security_group_id = module.security_group.security_group_id

  common_tags = local.common_tags

}
