locals {
  name_prefix   = lower("${var.project_name}-${var.environment}")
  db_identifier = lower("${local.name_prefix}-sqlserver")

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-db"
  }
}

