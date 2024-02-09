terraform {
  backend "s3" {
    bucket = "ci-cd-terraform-eks"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
