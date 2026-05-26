environment = "prod"
project     = "express-app"

vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

db_instance_class    = "db.t3.medium"
db_allocated_storage = 20
db_username          = "app_user"
db_password          = "prod_seguro_password_456"

ecs_app_image        = "624373582708.dkr.ecr.us-east-1.amazonaws.com/express/type:latest"
ecs_app_cpu          = 512
ecs_app_memory       = 1024
ecs_app_desired_count = 2
ecs_app_port         = 3000
