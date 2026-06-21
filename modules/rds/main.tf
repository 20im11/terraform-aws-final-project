data "aws_secretsmanager_secret_version" "db" {
  secret_id = var.secret_arn
}

resource "aws_db_subnet_group" "this" {
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "postgres" {
  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20

  db_name  = var.db_name
  username = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string).username
  password = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string).password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]

  skip_final_snapshot = true
}
