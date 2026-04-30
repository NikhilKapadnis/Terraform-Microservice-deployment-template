aws_region = "us-east-1"

vpc_id = "vpc-08e2b925c62ae9cfe"

private_subnet_ids = [
  "subnet-09bf2a896bccb2dbf",
  "subnet-058b43649e152e236",
]

ecs_cluster_name  = "nikhil-main-cluster"
ecs_service_sg_id = "sg-02786d507af1a3d34"

listener_arn = "arn:aws:elasticloadbalancing:us-east-1:306616136846:listener/app/nikhil-alb/447213bd5cc7bbd0/86dac35f0e241b65"

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