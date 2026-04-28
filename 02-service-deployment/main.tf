provider "aws" {
  region = var.aws_region
}

# ------------------------------
# ECR Repository
# ------------------------------
resource "aws_ecr_repository" "repo" {
  name = var.ecr_repo_name
}

# ------------------------------
# Target Group (per service)
# ------------------------------
resource "aws_lb_target_group" "tg" {
  name        = "${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = var.health_check_path
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ------------------------------
# Listener Rule (per service)
# ------------------------------
resource "aws_lb_listener_rule" "rule" {
  listener_arn = var.listener_arn
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    path_pattern {
      values = [var.path_pattern]
    }
  }
}

# ------------------------------
# ECS Task Definition (EC2)
# ------------------------------
resource "aws_ecs_task_definition" "task" {
  family                   = var.service_name
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${aws_ecr_repository.repo.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.service_name
        }
      }
    }
  ])
}

# ------------------------------
# ECS Service
# ------------------------------
resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"
  
  wait_for_steady_state = false

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener_rule.rule
  ]
}