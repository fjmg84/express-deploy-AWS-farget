# API Gateway REST - punto de entrada HTTP para las solicitudes externas
resource "aws_api_gateway_rest_api" "main" {
  # Nombre de la API ej: floci-api-dev
  name        = "${var.project}-api-${var.environment}"
  description = "API Gateway principal ${var.environment}"

  # Configuración del endpoint (REGIONAL = sin CloudFront)
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
  }
}

# Recurso comodín {proxy+} - captura cualquier ruta después de la base
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

# Método ANY - acepta cualquier verbo HTTP (GET, POST, PUT, DELETE, etc.)
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Integración HTTP proxy - reenvía las requests al backend (ALB/ECS)
resource "aws_api_gateway_integration" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  # HTTP_PROXY = reenvía la request tal cual al backend
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  # URL del backend (ALB interno)
  uri                     = "http://${var.alb_dns_name}/{proxy}"
}

# Deployment - publica los cambios de la API
resource "aws_api_gateway_deployment" "main" {
  depends_on  = [aws_api_gateway_integration.proxy]
  rest_api_id = aws_api_gateway_rest_api.main.id

  # Crea el nuevo deployment antes de destruir el anterior (evita downtime)
  lifecycle {
    create_before_destroy = true
  }
}

# Stage - entorno dentro de la API (dev, prod)
resource "aws_api_gateway_stage" "main" {
  # Nombre del stage (dev / prod)
  stage_name    = var.environment
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id

  # Variables de entorno disponibles en la API
  variables = {
    environment = var.environment
  }

  # Configura logs de acceso de la API en CloudWatch
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      sourceIp         = "$context.identity.sourceIp"
      method           = "$context.httpMethod"
      resourcePath     = "$context.resourcePath"
      status           = "$context.status"
      responseLatency  = "$context.responseLatency"
      requestTime      = "$context.requestTime"
    })
  }

  tags = {
    Environment = var.environment
  }
}
