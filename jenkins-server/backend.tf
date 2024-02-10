terraform {
  backend "s3" {
    bucket = "ci-cd-terraform-eks"
    key    = "jenkins/terraform.tfstate"
    region = "us-east-1"
  }
}
