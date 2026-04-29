aws_region = "us-east-1"

vpc_id = "vpc-0795788639f7facad"

private_subnet_ids = [
  "subnet-0888ddc8b5d54c063",
  "subnet-087e6809630bee696",
]

ecs_cluster_name  = "nikhil-main-cluster"
ecs_service_sg_id = "sg-0add7acb65a935308"

listener_arn = "arn:aws:elasticloadbalancing:us-east-1:306616136846:listener/app/nikhil-alb/5bd5757869e38635/c2b4c414c443c247"

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