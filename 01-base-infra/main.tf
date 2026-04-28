# ------------------------------
# AWS Provider
# Sets AWS as the Terraform provider and deploys resources in us-east-1.
# ------------------------------

provider "aws" {
  region = "us-east-1"
}


# ------------------------------
# VPC
# Creates the main isolated network for the infrastructure.
# All subnets, ALB, ECS cluster, NAT, and security groups belong to this VPC.
# ------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Nikhil-vpc"
  }
}


# ------------------------------
# Internet Gateway
# Allows public subnets to communicate with the internet.
# Required for the public ALB and NAT Gateway.
# ------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "nikhil-igw"
  }
}


# ------------------------------
# Public Subnet 1
# Creates a public subnet in availability zone us-east-1a.
# Public subnets are used for internet-facing resources like ALB and NAT Gateway.
# ------------------------------

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-1"
  }
}


# ------------------------------
# Public Subnet 2
# Creates a second public subnet in us-east-1b.
# ALB requires at least two subnets in different availability zones.
# ------------------------------

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-2"
  }
}


# ------------------------------
# Private Subnet 1
# Creates a private subnet in us-east-1a.
# ECS EC2 instances will run here, away from direct public internet access.
# ------------------------------

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-1"
  }
}


# ------------------------------
# Private Subnet 2
# Creates a second private subnet in us-east-1b.
# Gives ECS capacity better availability across multiple AZs.
# ------------------------------

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-2"
  }
}


# ------------------------------
# Elastic IP for NAT Gateway
# Creates a static public IP address used by the NAT Gateway.
# ------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nikhil-nat-eip"
  }
}


# ------------------------------
# NAT Gateway
# Allows private subnet resources to access the internet outbound.
# ECS EC2 instances need this to pull Docker images, send logs, and install updates.
# ------------------------------

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "nikhil-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}


# ------------------------------
# Public Route Table
# Routes public subnet traffic to the Internet Gateway.
# This makes public subnets internet-accessible.
# ------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "nikhil-public-rt"
  }
}


# ------------------------------
# Public Subnet 1 Route Table Association
# Connects public subnet 1 to the public route table.
# ------------------------------

resource "aws_route_table_association" "public_1" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_1.id
}


# ------------------------------
# Public Subnet 2 Route Table Association
# Connects public subnet 2 to the public route table.
# ------------------------------

resource "aws_route_table_association" "public_2" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_2.id
}


# ------------------------------
# Private Route Table
# Routes private subnet outbound internet traffic through NAT Gateway.
# Private resources do not receive direct inbound internet access.
# ------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "nikhil-private-rt"
  }
}


# ------------------------------
# Private Subnet 1 Route Table Association
# Connects private subnet 1 to the private route table.
# ------------------------------

resource "aws_route_table_association" "private_1" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_1.id
}


# ------------------------------
# Private Subnet 2 Route Table Association
# Connects private subnet 2 to the private route table.
# ------------------------------

resource "aws_route_table_association" "private_2" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_2.id
}


# ------------------------------
# ALB Security Group
# Allows HTTP traffic from the internet to the Application Load Balancer.
# The ALB will later forward traffic to ECS services.
# ------------------------------

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nikhil-alb-sg"
  }
}


# ------------------------------
# ECS EC2 Instance Security Group
# Allows traffic from the ALB to ECS EC2 container instances.
# The wide port range supports ECS dynamic host port mapping.
# ------------------------------

resource "aws_security_group" "ecs_instance_sg" {
  name        = "ecs-instance-sg"
  description = "Allow ALB traffic to ECS EC2 container instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nikhil-ecs-instance-sg"
  }
}


# ------------------------------
# ECS Cluster
# Creates the ECS cluster where EC2 container instances and ECS services will run.
# Container Insights is enabled for monitoring ECS metrics.
# ------------------------------

resource "aws_ecs_cluster" "main" {
  name = "nikhil-main-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "nikhil-main-cluster"
  }
}


# ------------------------------
# Application Load Balancer
# Creates an internet-facing ALB in public subnets.
# It receives external traffic and forwards it to service target groups.
# ------------------------------

resource "aws_lb" "main" {
  name               = "nikhil-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "nikhil-alb"
  }
}


# ------------------------------
# ALB HTTP Listener
# Creates an HTTP listener on port 80.
# Default action returns 404 until Stage 2 creates listener rules per service.
# ------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No service mapped yet"
      status_code  = "404"
    }
  }
}


# ------------------------------
# Shared CloudWatch Log Group
# Creates a shared log group for ECS service logs.
# Stage 2 services can reference this existing log group.
# ------------------------------

resource "aws_cloudwatch_log_group" "ecs_shared" {
  name              = "/ecs/nikhil-shared"
  retention_in_days = 7

  tags = {
    Name = "nikhil-ecs-shared-log-group"
  }
}


# ------------------------------
# ECS Task Execution Role
# Creates an IAM role used by ECS tasks.
# This role allows ECS tasks to pull images from ECR and send logs to CloudWatch.
# ------------------------------

resource "aws_iam_role" "ecs_shared_role" {
  name = "ecsSharedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ------------------------------
# ECS Task Execution Role Policy Attachment
# Attaches the AWS-managed ECS task execution policy.
# Required for pulling ECR images and writing logs.
# ------------------------------

resource "aws_iam_role_policy_attachment" "ecs_shared_role_policy" {
  role       = aws_iam_role.ecs_shared_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ------------------------------
# ECS EC2 Instance IAM Role
# Creates an IAM role for EC2 instances that run ECS containers.
# This is different from the ECS task execution role.
# ------------------------------

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ------------------------------
# ECS EC2 Instance Role Policy Attachment
# Allows EC2 instances to register with the ECS cluster and communicate with ECS.
# ------------------------------

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


# ------------------------------
# ECS EC2 Instance Profile
# Creates an instance profile so the ECS instance IAM role can be attached to EC2.
# EC2 uses instance profiles, not IAM roles directly.
# ------------------------------

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}


# ------------------------------
# ECS-Optimized AMI Lookup
# Finds the latest Amazon ECS-optimized Amazon Linux 2 AMI.
# This AMI includes the ECS agent required for EC2 instances to join ECS.
# ------------------------------

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}


# ------------------------------
# ECS Launch Template
# Defines the EC2 instance configuration used by the Auto Scaling Group.
# Includes AMI, instance type, security group, IAM profile, and ECS cluster join config.
# ------------------------------

resource "aws_launch_template" "ecs" {
  name_prefix   = "nikhil-ecs-lt-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [
    aws_security_group.ecs_instance_sg.id
  ]

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "nikhil-ecs-instance"
    }
  }
}


# ------------------------------
# ECS Auto Scaling Group
# Creates EC2 container instances for the ECS cluster.
# These EC2 instances provide shared compute capacity for ECS services.
# ------------------------------

resource "aws_autoscaling_group" "ecs" {
  name             = "nikhil-ecs-asg"
  desired_capacity = 1
  min_size         = 1
  max_size         = 2

  vpc_zone_identifier = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "nikhil-ecs-container-instance"
    propagate_at_launch = true
  }
}


# ------------------------------
# Output: VPC ID
# Used by Stage 2 to create service target groups inside the same VPC.
# ------------------------------

output "vpc_id" {
  value = aws_vpc.main.id
}


# ------------------------------
# Output: Public Subnet IDs
# Useful for reference/debugging. ALB is deployed in these subnets.
# ------------------------------

output "public_subnet_ids" {
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}


# ------------------------------
# Output: Private Subnet IDs
# Used by Stage 2 ECS services if networking config is needed.
# ECS EC2 capacity runs inside these private subnets.
# ------------------------------

output "private_subnet_ids" {
  value = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}


# ------------------------------
# Output: ALB Security Group ID
# Existing ALB security group reference.
# ------------------------------

output "alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}


# ------------------------------
# Output: ECS Instance Security Group ID
# Used as the shared ECS service/container instance security group.
# ------------------------------

output "ecs_instance_security_group_id" {
  value = aws_security_group.ecs_instance_sg.id
}


# ------------------------------
# Output: ALB ARN
# Useful reference for the shared Application Load Balancer.
# ------------------------------

output "alb_arn" {
  value = aws_lb.main.arn
}


# ------------------------------
# Output: ALB DNS Name
# Use this URL to test access to the ALB in browser.
# Before Stage 2, it should return "No service mapped yet".
# ------------------------------

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}


# ------------------------------
# Output: HTTP Listener ARN
# Stage 2 uses this to create listener rules for each microservice.
# ------------------------------

output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}


# ------------------------------
# Output: ECS Cluster ARN
# Reference to the shared ECS cluster.
# ------------------------------

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}


# ------------------------------
# Output: ECS Cluster Name
# Stage 2 uses this to deploy ECS services into the shared cluster.
# ------------------------------

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}


# ------------------------------
# Output: ECS Task Execution Role ARN
# Stage 2 task definitions use this role to pull ECR images and write logs.
# ------------------------------

output "ecs_shared_role_arn" {
  value = aws_iam_role.ecs_shared_role.arn
}


# ------------------------------
# Output: ECS EC2 Instance Role ARN
# Shows the IAM role used by ECS EC2 container instances.
# ------------------------------

output "ecs_instance_role_arn" {
  value = aws_iam_role.ecs_instance_role.arn
}


# ------------------------------
# Output: ECS EC2 Instance Profile Name
# Shows the instance profile attached to ECS EC2 instances.
# ------------------------------

output "ecs_instance_profile_name" {
  value = aws_iam_instance_profile.ecs_instance_profile.name
}


# ------------------------------
# Output: Shared CloudWatch Log Group Name
# Stage 2 services can use this existing log group for ECS logs.
# ------------------------------

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_shared.name
}


# ------------------------------
# Output: ECS Auto Scaling Group Name
# Shows the ASG providing EC2 capacity to the ECS cluster.
# ------------------------------

output "ecs_asg_name" {
  value = aws_autoscaling_group.ecs.name
}