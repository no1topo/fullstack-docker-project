# Application Load Balancer
resource "aws_lb" "main" {
  name_prefix        = "flsd"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  enable_http2       = true
  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })

  # Prevent accidental deletion of load balancer
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name_prefix]
  }
}

# Frontend Target Group
resource "aws_lb_target_group" "frontend" {
  name_prefix = "frt"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-tg"
  })
}

# Backend Target Group
resource "aws_lb_target_group" "backend" {
  name_prefix = "bck"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/ping"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-tg"
  })
}

# ALB Listener (HTTP on port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# API Rule: route /api/* to backend
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api*"]
    }
  }
}
