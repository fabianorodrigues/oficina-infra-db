resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security Group do RDS SQL Server da Oficina"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

resource "aws_security_group" "lambda_auth" {
  name        = "${local.name_prefix}-lambda-auth-sg"
  description = "Security Group da Lambda Auth da Oficina"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-lambda-auth-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_lambda_auth" {
  security_group_id = aws_security_group.rds.id
  description       = "SQL Server from Lambda security group"

  referenced_security_group_id = aws_security_group.lambda_auth.id
  from_port                    = 1433
  to_port                      = 1433
  ip_protocol                  = "tcp"

  tags = {
    Name = "${local.name_prefix}-rds-from-lambda-auth"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_operator" {
  count = var.enable_operator_db_access ? 1 : 0

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

resource "aws_vpc_security_group_ingress_rule" "rds_from_vpc" {
  security_group_id = aws_security_group.rds.id
  description       = "SQL Server from VPC CIDR for initial EKS integration"

  cidr_ipv4   = aws_vpc.main.cidr_block
  from_port   = 1433
  to_port     = 1433
  ip_protocol = "tcp"

  tags = {
    Name = "${local.name_prefix}-rds-from-vpc"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_auth_to_rds" {
  security_group_id = aws_security_group.lambda_auth.id
  description       = "SQL Server egress to RDS"

  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 1433
  to_port                      = 1433
  ip_protocol                  = "tcp"

  tags = {
    Name = "${local.name_prefix}-lambda-auth-to-rds"
  }
}
