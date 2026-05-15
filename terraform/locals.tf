locals {
  name_prefix                = lower(var.project_name)
  db_identifier              = lower("${local.name_prefix}-sqlserver")
  operator_db_access_enabled = nonsensitive(var.operator_cidr) != null

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-db"
  }
}
