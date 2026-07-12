

resource "aws_s3_bucket" "lab_bucket" {
  bucket = "om-devops-tf-lab-2026"

  tags = {
    Name  = "Terraform Lab Bucket"
    Owner = "Om"
  }
}
