# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379
  subnet_group_name    = var.subnet_group_name
  security_group_ids   = var.vpc_security_group_ids
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })

  # Prevent accidental deletion and allow reuse of existing cluster
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Redis Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.project_name}-${var.environment}-redis-params"
  family = "redis7"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis-params"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = all
  }
}

# Generate auth token
resource "random_password" "redis_auth" {
  length  = 32
  special = false  # Redis auth token doesn't support special characters
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "redis" {
  name              = "/aws/elasticache/${var.project_name}-${var.environment}-redis"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis-logs"
  })

  lifecycle {
    ignore_changes = all
  }
}

# Store Redis auth token in Secrets Manager
resource "aws_secretsmanager_secret" "redis_auth" {
  name_prefix = "${var.project_name}-${var.environment}-redis-auth-"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis-secret"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    host     = aws_elasticache_cluster.redis.cache_nodes[0].address
    port     = 6379
    password = random_password.redis_auth.result
  })
}
