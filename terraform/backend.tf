terraform {
  backend "s3" {
    key     = "oficina-infra-db/academy/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

