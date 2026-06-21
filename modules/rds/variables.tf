variable "vpc_id" {
  type = string
}

variable "db_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "secret_arn" {
  type = string
}

variable "db_name" {
  type = string
}
