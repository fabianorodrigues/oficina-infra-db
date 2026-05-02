variable "aws_region" {
  description = "Regiao AWS usada no AWS Academy Learner Lab."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado em nomes e tags."
  type        = string
  default     = "oficina"
}

variable "environment" {
  description = "Nome do ambiente usado em nomes e tags."
  type        = string
  default     = "academy"
}

variable "vpc_cidr" {
  description = "CIDR da VPC criada para o banco."
  type        = string
  default     = "10.30.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr deve ser um CIDR valido."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets publicas usadas pelo DB Subnet Group."
  type        = list(string)
  default     = ["10.30.1.0/24", "10.30.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_subnet_cidrs deve conter pelo menos 2 CIDRs validos."
  }
}

variable "db_name" {
  description = "Nome logico do banco usado pela aplicacao. Nao e enviado ao RDS SQL Server na criacao."
  type        = string
  default     = "OficinaDb"
}

variable "db_username" {
  description = "Usuario administrador do RDS SQL Server. Informe via TF_VAR_db_username ou terraform.tfvars local nao versionado."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,127}$", nonsensitive(var.db_username)))
    error_message = "db_username deve comecar com letra e conter apenas letras, numeros ou underscore."
  }
}

variable "db_password" {
  description = "Senha do usuario administrador do RDS SQL Server. Informe via TF_VAR_db_password ou terraform.tfvars local nao versionado."
  type        = string
  sensitive   = true

  validation {
    condition     = length(nonsensitive(var.db_password)) >= 8 && length(nonsensitive(var.db_password)) <= 128
    error_message = "db_password deve ter entre 8 e 128 caracteres."
  }
}

variable "db_instance_class" {
  description = "Classe da instancia RDS. Use db.t3.micro se disponivel no AWS Academy Learner Lab."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage alocado em GB para o RDS."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 100
    error_message = "O armazenamento deve estar entre 20 e 100 GB para compatibilidade com o AWS Academy."
  }
}

variable "backup_retention_period" {
  description = "Retencao de backups automatizados em dias. Use 0 para demo de baixo custo."
  type        = number
  default     = 0

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period deve ficar entre 0 e 35."
  }
}

variable "operator_cidr" {
  description = "CIDR /32 do IP publico do operador para acesso ao SQL Server via SSMS, sqlcmd ou API local."
  type        = string
  sensitive   = true

  validation {
    condition     = can(cidrhost(nonsensitive(var.operator_cidr), 0)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", nonsensitive(var.operator_cidr)))
    error_message = "operator_cidr deve ser um IPv4 /32, por exemplo 203.0.113.10/32."
  }
}

variable "skip_final_snapshot" {
  description = "Controla se o snapshot final sera ignorado ao destruir o RDS. Use true para demo."
  type        = bool
  default     = true
}
