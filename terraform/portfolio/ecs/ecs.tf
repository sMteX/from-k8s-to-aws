# logical grouping of ECS Fargate tasks
resource "aws_ecs_cluster" "portfolio" {
  name = "portfolio-ecs"
}

# IAM role for task execution
# ECS has *task execution role* (to let ECS pull image from ECR and push logs to Cloudwatch e.g.)
# and *task role* (permissions the *application code* uses at runtime if it needs)

# this resource is only a way to represent policy document using HCL. Doesn't create anything
data "aws_iam_policy_document" "ecs_task_trust" {
  statement {
    effect = "Allow"

    # something along the lines of "trust policy that allows the principal `ecs-tasks.amazonaws.com` (ECS's own service identity) is allowed to assume attached role?
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create the task execution role
resource "aws_iam_role" "ecs_execution" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust.json

  tags = {
    Service   = "ecs"
    ManagedBy = "terraform"
  }
}

# Attach the AWS managed execution role policy
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role = aws_iam_role.ecs_execution.name
  # Built-in, AWS managed policy that grants ECR read and CW Logs write
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "portfolio" {
  name = "portfolio-ecs"
}
data "aws_caller_identity" "current" {}
# Actual definition of the tash, "what to run"
resource "aws_ecs_task_definition" "portfolio" {
  family                   = "portfolio"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  # 256m, 512 Mi is the smallest Fargate instance
  cpu    = "256"
  memory = "512"
  container_definitions = jsonencode([
    {
      name   = "main"
      image  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.eu-central-1.amazonaws.com/portfolio-ecr:2026-09-21"
      cpu    = 256
      memory = 512
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.portfolio.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecs_service" "portfolio" {
  name            = "portfolio"
  cluster         = aws_ecs_cluster.portfolio.id
  task_definition = aws_ecs_task_definition.portfolio.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.caddy_ecs.id]
    subnets          = data.aws_subnets.default.ids
  }
}