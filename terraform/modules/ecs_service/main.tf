# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = var.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = var.service_name
    image     = var.ecr_image_uri
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.cloudwatch_log_group
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.service_name
      }
    }
    environment = concat(
      [
        {
          name  = "POSTGRES_HOST"
          value = var.rds_endpoint != null ? var.rds_endpoint : ""
        },
        {
          name  = "REDIS_HOST"
          value = var.redis_endpoint != null ? var.redis_endpoint : ""
        },
        {
          name  = "REQUEST_ORIGIN"
          value = "http://localhost"
        }
      ],
      var.additional_environment_variables
    )
  }])

  tags = merge(var.tags, {
    Name = "${var.service_name}-task-def"
  })

  depends_on = [var.cloudwatch_log_group]

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [family]
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_ecs_task_definition.main
  ]

  tags = merge(var.tags, {
    Name = var.service_name
  })

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [desired_count]
  }
}

data "aws_region" "current" {}
