resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security Group do RDS SQL Server da Oficina"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_vpc" {
  security_group_id = aws_security_group.rds.id
  description       = "SQL Server from VPC"

  cidr_ipv4   = var.vpc_cidr
  from_port   = 1433
  to_port     = 1433
  ip_protocol = "tcp"

  tags = {
    Name = "${local.name_prefix}-rds-from-vpc"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_operator" {
  security_group_id = aws_security_group.rds.id
  description       = "SQL Server from operator public IP"

  cidr_ipv4   = var.operator_cidr
  from_port   = 1433
  to_port     = 1433
  ip_protocol = "tcp"

  tags = {
    Name = "${local.name_prefix}-rds-from-operator"
  }
}
