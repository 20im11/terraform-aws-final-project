variable "private_subnets" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "secret_arn" {
  type = string
}
