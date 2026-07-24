locals {

  project_name = "terraform-modules"

  environment = "lab"

  owner = "Om"

  common_tags = {

    Project     = local.project_name
    Environment = local.environment
    Owner       = local.owner
    ManagedBy   = "Terraform"

  }

}