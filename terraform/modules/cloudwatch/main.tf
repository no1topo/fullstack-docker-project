# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-${var.environment}-backend"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-logs"
  })
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-${var.environment}-frontend"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-logs"
  })
}

# CloudWatch Alarms for Backend CPU
resource "aws_cloudwatch_metric_alarm" "backend_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when backend CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = "${var.project_name}-backend"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-cpu-alarm"
  })
}

# CloudWatch Alarms for Backend Memory
resource "aws_cloudwatch_metric_alarm" "backend_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when backend memory exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = "${var.project_name}-backend"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-memory-alarm"
  })
}
