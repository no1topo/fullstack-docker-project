# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.cluster_insights_enabled ? "enabled" : "disabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-cluster"
  })

  # Prevent accidental deletion of cluster
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name, setting]
  }
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}
