output "vpc_id" {
  description = "ID da VPC criada para o banco."
  value       = aws_vpc.main.id
  sensitive   = true
}

output "vpc_cidr_block" {
  description = "CIDR da VPC criada para a solucao."
  value       = aws_vpc.main.cidr_block
  sensitive   = true
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas usadas pelo EKS minimo e acesso operacional controlado."
  value       = aws_subnet.public[*].id
  sensitive   = true
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas usadas por RDS, Lambda Auth, NLB interno e VPC Link."
  value       = aws_subnet.private[*].id
  sensitive   = true
}

output "subnet_ids" {
  description = "Output legado mantido temporariamente para compatibilidade. Use public_subnet_ids ou private_subnet_ids."
  value       = aws_subnet.public[*].id
  sensitive   = true
}

output "lambda_subnet_id" {
  description = "ID da subnet privada que a Lambda Auth deve usar para acessar o RDS."
  value       = aws_subnet.private[0].id
  sensitive   = true
}

output "db_instance_identifier" {
  description = "Identificador da instancia RDS SQL Server."
  value       = aws_db_instance.oficina.identifier
  sensitive   = true
}

output "db_address" {
  description = "Endereco DNS do RDS SQL Server."
  value       = aws_db_instance.oficina.address
  sensitive   = true
}

output "db_port" {
  description = "Porta do RDS SQL Server."
  value       = aws_db_instance.oficina.port
}

output "db_name" {
  description = "Nome logico do banco esperado pela aplicacao. Criado pelas migrations do oficina-api."
  value       = var.db_name
}

output "lambda_security_group_id" {
  description = "ID do Security Group que a Lambda Auth deve usar."
  value       = aws_security_group.lambda_auth.id
  sensitive   = true
}

output "db_connection_string_without_password" {
  description = "Connection string sem usuario e sem senha para uso como base nos repos consumidores."
  value       = "Server=${aws_db_instance.oficina.address},${aws_db_instance.oficina.port};Database=${var.db_name};Encrypt=True;TrustServerCertificate=True;"
  sensitive   = true
}
