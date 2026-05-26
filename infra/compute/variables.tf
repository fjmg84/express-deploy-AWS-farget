variable "environment" {}
variable "project" {}
variable "ecs_app_image" {}
variable "ecs_app_cpu" {}
variable "ecs_app_memory" {}
variable "ecs_app_desired_count" {}
variable "ecs_app_port" {}
variable "vpc_id" {}
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "alb_security_group_id" {}
variable "ecs_security_group_id" {}
variable "db_host" {
  description = "RDS endpoint hostname"
  type        = string
}
variable "db_port" {
  description = "RDS port"
  type        = string
  default     = "5432"
}
variable "db_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}
variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
variable "db_name" {
  description = "RDS database name"
  type        = string
}
