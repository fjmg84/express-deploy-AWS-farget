output "vpc_id" {
  description = "ID de la VPC"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "DNS del ALB"
  value       = module.compute.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.compute.ecs_cluster_name
}

output "db_endpoint" {
  description = "Endpoint de RDS PostgreSQL"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "orders_queue_url" {
  description = "URL de la cola SQS de órdenes"
  value       = module.messaging.orders_queue_url
}

output "notifications_queue_url" {
  description = "URL de la cola SQS de notificaciones"
  value       = module.messaging.notifications_queue_url
}

output "api_gateway_url" {
  description = "URL del API Gateway"
  value       = module.api_gateway.api_gateway_url
}

output "ecs_log_group" {
  description = "Log group de CloudWatch para ECS"
  value       = module.monitoring.ecs_log_group
}
