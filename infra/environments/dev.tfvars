environment = "dev"
project     = "express-app"

vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-1a"]
public_subnet_cidrs  = ["10.0.101.0/24"]
private_subnet_cidrs = ["10.0.1.0/24"]

db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_username          = "app_user"
db_password          = "dev_seguro_password_123"

ecs_app_image        = "624373582708.dkr.ecr.us-east-1.amazonaws.com/express/type:latest"
ecs_app_cpu          = 256
ecs_app_memory       = 512
ecs_app_desired_count = 1
ecs_app_port         = 3000
