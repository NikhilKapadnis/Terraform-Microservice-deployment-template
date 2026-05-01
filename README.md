# Terraform-Microservice-deployment-template


Repo has 4 main parts:
.github/workflows/deploy.yml
01-base-infra/main.tf
02-service-deployment/main.tf
app/
 The repo is mostly Terraform/HCL, with some JavaScript and Dockerfile code.
Overall project purpose
This project creates a reusable AWS deployment template for a microservice.

The flow is:
Developer pushes code to GitHub main
       ↓
GitHub Actions runs deploy.yml
       ↓
Docker image is built from /app
       ↓
Image is pushed to AWS ECR
       ↓
Terraform deploys ECS service
       ↓
ALB receives browser/API traffic
       ↓
ALB listener rule forwards traffic to ECS target group
       ↓
ECS runs container on EC2 instance
       ↓
Logs go to CloudWatch

1. 01-base-infra: shared AWS infrastructure
This is the foundation layer. You run this first.
It creates:
VPC
Internet Gateway
Public subnets
Private subnets
NAT Gateway
Route tables
Security groups
ECS cluster
Application Load Balancer
CloudWatch log group
IAM roles
Launch template
Auto Scaling Group
VPC
aws_vpc.main
Creates the private AWS network:
10.0.0.0/16
Everything else lives inside this VPC: subnets, ALB, ECS, security groups, NAT gateway. DNS support is enabled, which helps AWS services resolve internal/public names.
Think of the VPC as your private AWS data center.

Internet Gateway
aws_internet_gateway.igw
This gives the VPC access to the public internet.
It is mainly used by:
Public subnets
Application Load Balancer
NAT Gateway
Without this, public resources cannot receive internet traffic.

Public subnets
aws_subnet.public_1
aws_subnet.public_2
You have two public subnets:
10.0.1.0/24 → us-east-1a
10.0.2.0/24 → us-east-1b
These are public because:
map_public_ip_on_launch = true
and because their route table sends traffic to the Internet Gateway.
The ALB lives here. ALB requires at least two subnets in different Availability Zones, so using public_1 and public_2 is correct.

Private subnets
aws_subnet.private_1
aws_subnet.private_2
You have two private subnets:
10.0.11.0/24 → us-east-1a
10.0.12.0/24 → us-east-1b
These are where your ECS EC2 instances run.
Important point: your actual containers are not directly exposed to the internet. They sit privately. The public entry point is only the ALB.
That is the right design.

NAT Gateway
aws_nat_gateway.nat
aws_eip.nat
Private subnet resources still need outbound internet access for things like:
pulling Docker images
sending logs
installing updates
talking to AWS APIs
But they should not be directly reachable from the internet.
That is what NAT Gateway does:
Private ECS instance → NAT Gateway → Internet
The Elastic IP gives the NAT Gateway a fixed public IP.

Route tables
You have two route tables.
Public route table
aws_route_table.public
It sends:
0.0.0.0/0 → Internet Gateway
Meaning: all internet-bound traffic from public subnets goes directly to the internet.
Private route table
aws_route_table.private
It sends:
0.0.0.0/0 → NAT Gateway
Meaning: private subnet instances can go out to the internet, but external users cannot directly come in.

2. Security Groups
ALB security group
aws_security_group.alb_sg
Allows:
Inbound HTTP 80 from 0.0.0.0/0
Outbound all traffic
So anyone on the internet can hit your ALB over HTTP.
This is your public-facing firewall.

ECS instance security group
aws_security_group.ecs_instance_sg
Allows traffic only from the ALB security group.
Important part:
security_groups = [aws_security_group.alb_sg.id]
That means ECS instances do not accept random internet traffic. They only accept traffic coming from the ALB.
It allows ports 0–65535 because ECS is using dynamic host port mapping.

3. ECS Cluster
aws_ecs_cluster.main
Creates:
nikhil-main-cluster
This is the logical ECS cluster where your services run.
Your project uses ECS with EC2 launch type, not Fargate.
That means:
You manage EC2 capacity
ECS schedules containers onto EC2 instances
Auto Scaling Group provides the machines
Container Insights is enabled for monitoring.

4. Application Load Balancer
aws_lb.main
Creates:
nikhil-alb
It is:
internal = false
load_balancer_type = "application"
So it is internet-facing.
It sits in the two public subnets and receives user traffic.

ALB listener
aws_lb_listener.http
Listens on:
HTTP port 80
Default behavior:
Return 404: "No service mapped yet"
That means Stage 1 only creates the ALB. It does not yet know which service should receive traffic.
Stage 2 adds listener rules.

5. CloudWatch Logs
aws_cloudwatch_log_group.ecs_shared
Creates:
/ecs/nikhil-shared
Your ECS containers send logs here.
Retention:
7 days
So logs are automatically deleted after 7 days.

6. IAM roles
ECS task execution role
aws_iam_role.ecs_shared_role
Used by ECS tasks to:
Pull images from ECR
Write logs to CloudWatch
It attaches:
AmazonECSTaskExecutionRolePolicy
This is required for normal ECS container startup.

ECS EC2 instance role
aws_iam_role.ecs_instance_role
This role is attached to the EC2 instances that join the ECS cluster.
It lets EC2:
Register with ECS
Receive tasks
Communicate with ECS agent
It attaches:
AmazonEC2ContainerServiceforEC2Role
Then it is wrapped inside:
aws_iam_instance_profile.ecs_instance_profile
EC2 instances cannot directly attach IAM roles; they use instance profiles.

7. ECS EC2 capacity
ECS optimized AMI
data "aws_ami" "ecs_optimized"
Finds the latest ECS-optimized Amazon Linux 2 AMI.
This AMI already includes the ECS agent, which lets the EC2 instance join the ECS cluster.

Launch template
aws_launch_template.ecs
Defines how ECS EC2 instances should be created:
AMI: ECS optimized AMI
Instance type: t3.micro
Security group: ECS instance SG
IAM profile: ECS instance profile
It also contains user data that configures the ECS cluster name, so the instance joins:
nikhil-main-cluster
This is what connects EC2 capacity to ECS.

Auto Scaling Group
aws_autoscaling_group.ecs
Creates EC2 instances in private subnets.
Config:
desired_capacity = 1
min_size = 1
max_size = 2
So normally one EC2 instance runs, but it can scale to two.
This ASG provides the compute capacity where ECS places containers.

8. Outputs from 01-base-infra
At the end, Stage 1 outputs values like:
vpc_id
private_subnet_ids
alb_security_group_id
ecs_instance_security_group_id
alb_arn
alb_dns_name
http_listener_arn
ecs_cluster_name
ecs_shared_role_arn
cloudwatch_log_group_name
ecs_asg_name
These outputs are needed by Stage 2.
Your Stage 2 terraform.tfvars manually pastes these values.

9. 02-service-deployment: per-service deployment
This is the reusable service layer.
You run this every time you want to deploy a microservice.
It creates:
ECR repository
ALB target group
ALB listener rule
ECS task definition
ECS service

ECR repository
aws_ecr_repository.repo
Creates a Docker image repository:
name = var.ecr_repo_name
For your current config:
notification-service
This is where your Docker image is pushed.

Target group
aws_lb_target_group.tg
Creates a target group for this service.
Config:
Name: notification-service-tg
Port: 3000
Protocol: HTTP
Target type: instance
Because target type is instance, the ALB sends traffic to EC2 instances, not directly to individual task ENIs.
Health check:
Path: /health
Matcher: 200-299
Interval: 30 seconds
Timeout: 5 seconds
Healthy threshold: 2
Unhealthy threshold: 3
So AWS checks /health. If the container returns a 2xx response, the target is healthy.

Listener rule
aws_lb_listener_rule.rule
Connects ALB traffic to this service.
Your config:
path_pattern = "/*"
listener_priority = 100
Meaning:
Any path coming to the ALB should forward to notification-service target group
For one service, /* is fine.
For multiple microservices, you would use:
/api/users/*
/api/orders/*
/api/notifications/*
Each service needs a unique listener priority.

ECS task definition
aws_ecs_task_definition.task
This is the container blueprint.
It says:
Run this image
Use this CPU
Use this memory
Expose this container port
Send logs here
Your values:
service_name = notification-service
container_port = 3000
cpu = 256
memory = 512
image_tag = PLACEHOLDER / GitHub SHA during CI
It uses:
requires_compatibilities = ["EC2"]
network_mode = "bridge"
This means the container runs on ECS EC2 instances using Docker bridge networking.
Important part:
hostPort = 0
That means ECS chooses a random available host port on the EC2 instance.
Example:
Container port: 3000
Host port: 32768
The ALB target group maps traffic to that dynamic host port. This is why the ECS instance security group allows a wide port range from the ALB.

ECS service
aws_ecs_service.service
This keeps the container running.
Config:
Service name: notification-service
Cluster: nikhil-main-cluster
Desired count: 1
Launch type: EC2
It attaches the ECS service to the target group.
So ECS does this:
Start container
Register container/EC2/port with target group
Keep desired_count containers alive
Restart if unhealthy
It depends on the listener rule, so Terraform creates routing before the service attempts to attach to the ALB.

10. terraform.tfvars
This file provides actual values for the variables.
Current service:
service_name = notification-service
ecr_repo_name = notification-service
container_port = 3000
desired_count = 1
health_check_path = /health
path_pattern = /*
It also includes infrastructure IDs from Stage 1:
vpc_id
private_subnet_ids
ecs_cluster_name
listener_arn
task_execution_role_arn
log_group_name
Realistically: hardcoding these IDs works for learning, but for production, it is weak. Better approach is remote Terraform state, SSM parameters, or data sources.

11. GitHub Actions deployment flow
Your workflow runs on push to main.
It does:
Checkout code
Install Terraform
Configure AWS credentials
terraform init
Login to ECR
Ensure ECR repo exists
Build Docker image
Tag image with GitHub commit SHA
Push image to ECR
terraform apply with image_tag=$GITHUB_SHA
The image tag is not fixed. It uses:
github.sha
That is good because every commit gets a unique Docker image tag.

12. Full runtime request flow
When someone opens the ALB URL:
1. User sends HTTP request to ALB DNS name
2. ALB receives request on port 80
3. Listener checks rules
4. Path /* matches notification-service rule
5. ALB forwards request to notification-service target group
6. Target group sends request to ECS EC2 instance dynamic host port
7. Docker forwards host port to container port 3000
8. Node service handles request
9. Response goes back:
  Container → ECS EC2 → ALB → User

13. Deployment flow
When you push code:
1. GitHub Actions starts
2. Docker image is built from app/
3. Image is pushed to ECR:
  notification-service:<commit-sha>
4. Terraform updates ECS task definition with new image tag
5. ECS service sees new task definition
6. ECS starts new container
7. ALB health check calls /health
8. If healthy, traffic goes to new container

14. What is good in this project
Good parts:
VPC separated into public/private subnets
ALB public, ECS private
NAT Gateway for private outbound access
ECS EC2 cluster created properly
CloudWatch logs enabled
Reusable Stage 2 service deployment
GitHub Actions builds and pushes image
Image tagged by commit SHA
This is a solid beginner-to-intermediate AWS ECS Terraform template.

15. Problems / improvements
Realistic issues:
HTTP only, no HTTPS
No ACM certificate
No Route 53 domain
NAT Gateway costs money
Terraform state appears local, not remote
terraform.tfvars has hardcoded AWS resource IDs
Task role and execution role are the same
No autoscaling policy for ECS service
No remote backend like S3 + DynamoDB locking
No secrets management
No blue/green deployment
No private ECR VPC endpoints
Most important improvement:
Add remote Terraform backend.
Right now, if Terraform state is local, it is risky. In real projects, use:
S3 bucket for Terraform state
DynamoDB table for state lock
Second important improvement:
Use separate IAM task role.
Execution role should pull image/write logs. Task role should be for app permissions only.

16. Simple mental model
Think of the project as two layers:
01-base-infra = build the road, buildings, gates, security, cluster
02-service-deployment = put one app/service into that infrastructure
And GitHub Actions automates:
code → Docker image → ECR → ECS update
That is the full project flow.

