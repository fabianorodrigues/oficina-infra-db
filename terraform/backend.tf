terraform {
  backend "s3" {
    key     = "oficina-infra-db/dev/terraform.tfstate"
    encrypt = true
  }
}
