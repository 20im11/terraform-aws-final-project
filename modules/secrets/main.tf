resource "random_password" "db" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name = "db-secret"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_user
    password = random_password.db.result
  })
}
