

locals {
  project_name = "terraform-aws-lab"
  environment  = "dev"

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = "Om"
  }
}
