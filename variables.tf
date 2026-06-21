variable "project_name" {
  default = "three-tier"
}

variable "environment" {
  default = "prod"
}

variable "primary_region" {
  default = "eu-central-1"
}

variable "secondary_region" {
  default = "eu-west-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "db_name" {
  default = "appdb"
}

variable "db_user" {
  default = "postgres"
}

variable "notification_email" {
  type = string
}