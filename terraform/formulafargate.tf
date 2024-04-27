provider "aws" {
  region = "us-east-1" # Set your desired AWS region
}

# Create an ECS cluster
resource "aws_ecs_cluster" "formulamonks" {
  name = "formulamonks"
}

# Create an IAM role for CodeBuild
resource "aws_iam_role" "codebuild_formulamonksrole" {
  name               = "codebuild-formulamonksrole"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

# Attach policies to the CodeBuild role
resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_formulamonksrole.name
  policy_arn = "arn:aws:iam::361115084383:policy/AWSCodePipelineFullAccess"
}

# Create a CodeBuild project
resource "aws_codebuild_project" "formulamonks" {
  name          = "formulamonks"
  description   = "CodeBuild project for building Docker images"
  service_role  = aws_iam_role.codebuild_formulamonksrole.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# Create an ECS task definition
resource "aws_ecs_task_definition" "formulamonks" {
  family                   = "formulamonks"
  network_mode             = "awsvpc" # Required for Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "arn:aws:iam::361115084383:role/ecs-task-execution-role"
  container_definitions    = jsonencode([
    {
      name      = "formulamonks-container"
      image     = "361115084383.dkr.ecr.us-east-1.amazonaws.com/lichi:speedtest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 5000 # Replace with the port your container is listening on
          hostPort      = 5000
        }
      ]
    }
  ])
}

# Create an Application Load Balancer
resource "aws_lb" "formulamonks_alb" {
  name               = "formulamonks-alb"
  load_balancer_type = "application"
  security_groups    = ["sg-04266e1cc07761c02"] # Replace with your security group ID
  subnets            = ["subnet-0fb5793f4c48205e7", "subnet-019ab9f65a08f571a"] 
}

# Create a Target Group for the Fargate Service
resource "aws_lb_target_group" "formulamonks_tg" {
  name        = "formulamonks-tg"
  port        = 5000 # Replace with the port your container is listening on
  protocol    = "HTTP"
  vpc_id      = "vpc-0a81157919f8aa61c" # Replace with your VPC ID
  target_type = "ip"

  health_check {
    path = "/" # Replace with the health check path for your application
  }
}

# Create a Load Balancer Listener
resource "aws_lb_listener" "formulamonks_listener" {
  load_balancer_arn = aws_lb.formulamonks_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.formulamonks_tg.arn
  }
}

# Create an ECS service
resource "aws_ecs_service" "formulamonks" {
  name            = "formulamonks-service"
  cluster         = aws_ecs_cluster.formulamonks.id
  task_definition = aws_ecs_task_definition.formulamonks.arn
  desired_count   = 1
  launch_type     = "FARGATE" # Use Fargate as the launch type

  network_configuration {
    subnets          = ["subnet-0fb5793f4c48205e7"] # Specify the subnet IDs for the Fargate task
    security_groups  = ["sg-04266e1cc07761c02"]     # Specify the security group IDs for the Fargate task
    assign_public_ip = true                         # Assign a public IP address to the Fargate task
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.formulamonks_tg.arn
    container_name   = "formulamonks-container"
    container_port   = 5000 # Replace with the port your container is listening on
  }
} # Added the missing closing brace here
