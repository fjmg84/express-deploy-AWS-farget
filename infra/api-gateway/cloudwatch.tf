# Grupo de logs para API Gateway - almacena los logs de acceso de la API
resource "aws_cloudwatch_log_group" "api_gateway" {
  # Nombre del grupo de logs ej: /aws/api-gateway/floci-dev
  name              = "/aws/api-gateway/${var.project}-${var.environment}"
  # Días que se retienen los logs (30 en prod, 7 en dev)
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = {
    Environment = var.environment
  }
}
