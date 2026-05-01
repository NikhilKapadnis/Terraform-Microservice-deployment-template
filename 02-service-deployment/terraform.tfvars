aws_region = "us-east-1"

vpc_id = "vpc-08ed0641672b935c7"

private_subnet_ids = [
  "subnet-0ed22f0b505d5ef20",
  "subnet-0c617ef2d3ae43572",
]

ecs_cluster_name  = "nikhil-main-cluster"
ecs_service_sg_id = "sg-0a813fdc90b1c207e"

listener_arn = "arn:aws:elasticloadbalancing:us-east-1:306616136846:listener/app/nikhil-alb/45ac8585310822cf/b39bd7b4c69e5506"

task_execution_role_arn = "arn:aws:iam::306616136846:role/ecsSharedRole"
task_role_arn           = "arn:aws:iam::306616136846:role/ecsSharedRole"

log_group_name = "/ecs/nikhil-shared"

service_name      = "notification-service"
ecr_repo_name     = "notification-service"
container_port    = 3000
image_tag         = "PLACEHOLDER"
cpu               = 256
memory            = 512
desired_count     = 1
health_check_path = "/health"
listener_priority = 100
path_pattern      = "/*"