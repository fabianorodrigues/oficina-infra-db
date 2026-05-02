resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "oficina" {
  identifier = local.db_identifier

  engine         = "sqlserver-ex"
  license_model  = "license-included"
  instance_class = var.db_instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  username = var.db_username
  password = var.db_password
  port     = 1433

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  multi_az                     = false
  monitoring_interval          = 0
  performance_insights_enabled = false

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = false
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.db_identifier}-final-snapshot"

  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = {
    Name = local.db_identifier
  }
}
