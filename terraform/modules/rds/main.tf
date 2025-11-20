# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier              = "${var.project_name}-${var.environment}-postgres"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = var.storage_type
  storage_encrypted       = true
  db_name                 = "postgres"
  username                = "postgres"
  password                = random_password.db_password.result
  parameter_group_name    = aws_db_parameter_group.postgres.name
  db_subnet_group_name    = var.db_subnet_group_name
  vpc_security_group_ids  = var.vpc_security_group_ids
  backup_retention_period = var.backup_retention_days
  multi_az                = var.multi_az
  skip_final_snapshot     = var.environment == "dev" ? true : false
  copy_tags_to_snapshot   = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-postgres"
  })

  # Prevent accidental deletion of database
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.project_name}-${var.environment}-"
  family      = "postgres16"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-pg-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Generate random password
resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%^&*()-_=+{}[]:,.?" # exclude '/', '@', '"', and space
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix = "${var.project_name}-${var.environment}-db-password-"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.db_password.result
    host     = aws_db_instance.postgres.address
    port     = 5432
    database = "postgres"
  })
}
