# Módulo de red - crea VPC, subnets, security groups, internet gateway
module "networking" {
  source = "./networking"

  region               = var.region
  environment          = var.environment
  project              = var.project
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  ecs_app_port         = var.ecs_app_port
}

# Módulo de base de datos - crea RDS PostgreSQL y su grupo de parámetros
module "database" {
  source = "./database"

  environment           = var.environment
  project               = var.project
  db_instance_class     = var.db_instance_class
  db_allocated_storage  = var.db_allocated_storage
  db_username           = var.db_username
  db_password           = var.db_password
  rds_security_group_id = module.networking.rds_security_group_id
}

# Módulo de mensajería - crea colas SQS para pedidos y notificaciones
module "messaging" {
  source = "./messaging"

  environment = var.environment
  project     = var.project
}

# Módulo de cómputo - crea ECS (cluster, tareas, servicio), ALB, roles IAM
module "compute" {
  source = "./compute"

  environment           = var.environment
  project               = var.project
  ecs_app_image         = var.ecs_app_image
  ecs_app_cpu           = var.ecs_app_cpu
  ecs_app_memory        = var.ecs_app_memory
  ecs_app_desired_count = var.ecs_app_desired_count
  ecs_app_port          = var.ecs_app_port
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  ecs_security_group_id = module.networking.ecs_security_group_id
  db_host               = module.database.db_address
  db_port               = "5432"
  db_username           = var.db_username
  db_password           = var.db_password
  db_name               = module.database.db_name
}

# Módulo de API Gateway - expone una API REST que apunta al backend
module "api_gateway" {
  source = "./api-gateway"

  environment  = var.environment
  project      = var.project
  alb_dns_name = module.compute.alb_dns_name
}

# Módulo de monitoreo - crea grupos de logs y alarmas de CloudWatch
module "monitoring" {
  source = "./monitoring"

  environment      = var.environment
  project          = var.project
  ecs_cluster_name = module.compute.ecs_cluster_name
  alb_arn          = module.compute.alb_arn
  db_identifier    = module.database.db_instance_identifier
}
