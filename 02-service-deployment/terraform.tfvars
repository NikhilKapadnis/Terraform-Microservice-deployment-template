aws_region = "us-east-1"

vpc_id = "vpc-0b42e95e53cc8ae2e"

private_subnet_ids = [
  "subnet-0bd4beb7e55a5bc05",
  "subnet-02c60244a74a83217",
]

ecs_cluster_name  = "nikhil-main-cluster"
ecs_service_sg_id = "sg-0bd05e51edf2ff747"

listener_arn = "arn:aws:elasticloadbalancing:us-east-1:306616136846:listener/app/nikhil-alb/398b451444042a56/cb421d7c45155400"

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