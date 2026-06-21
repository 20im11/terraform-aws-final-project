############################################
# Cluster
############################################

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

############################################
# CloudWatch log group (container logs)
############################################

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-app"
  retention_in_days = 7
}

############################################
# IAM roles
############################################

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: lets Fargate pull the image and write logs.
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: lets the running app read the DB secret from Secrets Manager.
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "task" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.secret_arn]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${var.project_name}-read-secret"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

############################################
# Task definition
#
# Uses a stock Python image and bootstraps the
# Flask app at start: installs deps (reaching the
# internet through the NAT Gateway) and runs the
# app source injected via the APP_CODE env var.
############################################

resource "aws_ecs_task_definition" "this" {
  family = "${var.project_name}-app"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024

  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "public.ecr.aws/docker/library/python:3.11-slim"
    essential = true

    command = [
      "sh", "-c",
      "pip install --no-cache-dir --quiet flask psycopg2-binary boto3 && printf '%s' \"$APP_CODE\" > /tmp/app.py && exec python /tmp/app.py"
    ]

    portMappings = [{
      containerPort = 5000
    }]

    environment = [
      { name = "APP_CODE", value = file("${path.root}/app/app.py") },
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = tostring(var.db_port) },
      { name = "DB_NAME", value = var.db_name },
      { name = "SECRET_ARN", value = var.secret_arn },
      { name = "AWS_REGION", value = var.region },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

############################################
# Service
############################################

resource "aws_ecs_service" "this" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 180

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [var.ecs_sg_id]
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = 5000
  }
}
