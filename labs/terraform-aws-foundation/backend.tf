
terraform {
  backend "s3" {
    bucket       = "omp-terraform-state-2026"
    key          = "terraform-aws-foundation/terraform.tfstate"
    region       = "us-east-1"
    profile      = "om-Devops"
    encrypt      = true
    use_lockfile = true
  }
}
