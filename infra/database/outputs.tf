output "database_identifier" {
  value       = aws_db_instance.database.identifier
  description = "Value of the database identifier"
}

output "database_host" {
  value       = aws_db_instance.database.address
  description = "Value of the database host"
}

output "database_port" {
  value       = aws_db_instance.database.port
  description = "Value of the database port"
}
