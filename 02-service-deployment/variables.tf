variable "aws_region" { type = string }

# Stage 1 inputs (paste from your outputs / excel)
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_sg_id" { type = string }
variable "listener_arn" { type = string }
variable "task_execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "log_group_name" { type = string }

# Service-specific
variable "service_name" { type = string }
variable "ecr_repo_name" { type = string }
variable "container_port" { type = number }
variable "image_tag" { type = string }
variable "cpu" { type = number }
variable "memory" { type = number }
variable "desired_count" { type = number }
variable "health_check_path" { type = string }
variable "listener_priority" { type = number }
variable "path_pattern" { type = string }