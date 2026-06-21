module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
}

module "security_groups" {
  source = "./modules/security"

  vpc_id = module.vpc.vpc_id
}

module "secrets" {
  source = "./modules/secrets"

  db_user = var.db_user
}

module "rds" {
  source = "./modules/rds"

  vpc_id        = module.vpc.vpc_id
  db_subnet_ids = module.vpc.db_subnet_ids
  rds_sg_id     = module.security_groups.rds_sg_id
  secret_arn    = module.secrets.secret_arn
  db_name       = var.db_name
}

module "alb" {
  source = "./modules/alb"

  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  alb_sg_id      = module.security_groups.alb_sg_id
}

module "ecs" {
  source = "./modules/ecs"

  project_name = var.project_name
  region       = var.primary_region

  private_subnets = module.vpc.app_subnet_ids
  ecs_sg_id       = module.security_groups.ecs_sg_id

  target_group_arn = module.alb.target_group_arn

  db_host = module.rds.address
  db_port = module.rds.port
  db_name = var.db_name

  secret_arn = module.secrets.secret_arn
}

module "s3" {
  source = "./modules/s3"

  providers = {
    aws.secondary = aws.secondary
  }

  project_name = var.project_name
}

module "sns" {
  source = "./modules/sns"

  email = var.notification_email
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  sns_topic_arn = module.sns.topic_arn
  cluster_name  = module.ecs.cluster_name
  service_name  = module.ecs.service_name
}
