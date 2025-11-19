output "primary_endpoint_address" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "port" {
  value = 6379
}

output "secret_arn" {
  value = aws_secretsmanager_secret.redis_auth.arn
}
