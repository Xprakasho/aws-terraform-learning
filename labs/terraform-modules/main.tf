
module "network" {

  source = "./modules/network"

  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone

}

module "compute" {

  source = "./modules/compute"

  ami_id        = "ami-052355af2a014bd2c"
  instance_type = "t3.micro"
  subnet_id     = module.network.subnet_id
  instance_name = "Terraform-Module-EC2"

}
