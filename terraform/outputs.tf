output "vpc_id" {
  description = "ID da VPC criada para o banco."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas usadas pelo DB Subnet Group."
  value       = aws_subnet.public[*].id
}

output "db_endpoint" {
  description = "Endpoint completo do RDS SQL Server, incluindo porta."
  value       = aws_db_instance.oficina.endpoint
}

output "db_address" {
  description = "Endereco DNS do RDS SQL Server."
  value       = aws_db_instance.oficina.address
}

output "db_port" {
  description = "Porta do RDS SQL Server."
  value       = aws_db_instance.oficina.port
}

output "db_name" {
  description = "Nome logico do banco esperado pela aplicacao. Criado pelas migrations do oficina-api."
  value       = var.db_name
}

output "db_security_group_id" {
  description = "ID do Security Group associado ao RDS."
  value       = aws_security_group.rds.id
}

output "db_connection_string_without_password" {
  description = "Connection string sem usuario e sem senha para uso como base nos repos consumidores."
  value       = "Server=${aws_db_instance.oficina.address},${aws_db_instance.oficina.port};Database=${var.db_name};Encrypt=True;TrustServerCertificate=True;"
}

