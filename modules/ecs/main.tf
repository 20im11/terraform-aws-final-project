resource "aws_ecs_cluster" "this" {
  name = "cluster"
}

resource "aws_ecs_task_definition" "this" {
  family = "app"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name  = "app"
    image = "nginx"
    portMappings = [{
      containerPort = 5000
    }]
    environment = [
      {
        name  = "DB_ENDPOINT"
        value = var.db_endpoint
      },
      {
        name  = "SECRET_ARN"
        value = var.secret_arn
      }
    ]
  }])
}

resource "aws_ecs_service" "this" {
  name            = "service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2
  launch_type     = "FARGATE"

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
