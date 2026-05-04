terraform {
  backend "s3" {
    key     = "oficina-infra-db/academy/terraform.tfstate"
    encrypt = true
  }
}
