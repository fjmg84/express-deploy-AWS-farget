variable "region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno (dev | prod)"
  type        = string
}

variable "project" {
  description = "Nombre del proyecto"
  type        = string
  default     = "floci"
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Zonas de disponibilidad"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks para subnets privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks para subnets públicas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "db_instance_class" {
  description = "Instancia RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Storage en GB para RDS"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "Usuario master de la BD"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password master de la BD"
  type        = string
  sensitive   = true
}

variable "ecs_app_image" {
  description = "Imagen Docker para el servicio app"
  type        = string
  default     = "nginx:alpine"
}

variable "ecs_app_cpu" {
  description = "CPU para tarea ECS app (en unidades)"
  type        = number
  default     = 512
}

variable "ecs_app_memory" {
  description = "Memoria para tarea ECS app (en MB)"
  type        = number
  default     = 1024
}

variable "ecs_app_desired_count" {
  description = "Cantidad deseada de instancias del servicio app"
  type        = number
  default     = 2
}

variable "ecs_app_port" {
  description = "Puerto del contenedor app"
  type        = number
  default     = 80
}
