# Grupo de logs para las tareas ECS - almacena los logs del contenedor
resource "aws_cloudwatch_log_group" "ecs_app" {
  # Nombre del grupo (debe coincidir con el configurado en la task definition)
  name              = "/ecs/${var.project}-app-${var.environment}"
  # Días que se retienen los logs (30 en prod, 7 en dev)
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = {
    Environment = var.environment
  }
}

# Grupo de logs para RDS - almacena logs de la base de datos (error, slow query, etc.)
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.project}-pg-${var.environment}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = {
    Environment = var.environment
  }
}
