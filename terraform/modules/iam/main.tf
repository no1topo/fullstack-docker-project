# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix = "${var.project_name}-ecs-task-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-task-exec-role"
  })

  # Allow replacement without disrupting service
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Policy for ECR access
resource "aws_iam_role_policy" "ecs_task_execution_ecr" {
  name_prefix = "${var.project_name}-ecr-"
  role        = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
      Resource = "*"
    }]
  })
}

# IAM Role for Backend Tasks
resource "aws_iam_role" "backend_task_role" {
  name_prefix = "${var.project_name}-backend-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-task-role"
  })

  # Replace without downtime
  lifecycle {
    create_before_destroy = true
  }
}

# IAM Role for Frontend Tasks
resource "aws_iam_role" "frontend_task_role" {
  name_prefix = "${var.project_name}-frontend-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-task-role"
  })

  # Replace without downtime
  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Logs policy for both task roles
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name_prefix = "${var.project_name}-logs-"
  role        = aws_iam_role.backend_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# IAM Policy for Secrets Manager (Needed for Execution Role to pull DB password)
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name_prefix = "${var.project_name}-secrets-"
  role        = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      # Set the ARN specifically to your secrets for best security practice.
      # Using a dynamic resource pattern is safer than "*".
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret/*"
    }]
  })
}

# Add this data block needed for the Resource ARN above
data "aws_caller_identity" "current" {}
