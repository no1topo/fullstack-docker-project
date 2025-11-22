output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "database_name" {
  value = aws_db_instance.postgres.db_name
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}

output "rds_port" {
  # Port number only
  value = aws_db_instance.postgres.port
}