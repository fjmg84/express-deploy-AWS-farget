# Cluster ECS - agrupa las tareas y servicios de contenedores
resource "aws_ecs_cluster" "main" {
  # Nombre del cluster ej: floci-cluster-dev
  name = "${var.project}-cluster-${var.environment}"

  # Habilita Container Insights (monitoreo de métricas del cluster)
  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled"
  }

  tags = {
    Environment = var.environment
  }
}

# Define qué tipos de cómputo puede usar el cluster (Fargate on-demand y spot)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  # FARGATE = precio completo, FARGATE_SPOT = más barato pero pueden interrumpirse
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Estrategia por defecto: cuántas tareas van a FARGATE vs FARGATE_SPOT
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.environment == "prod" ? 1 : 0
    base             = var.environment == "prod" ? 1 : 0
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.environment == "prod" ? 0 : 1
  }
}

# Definición de la tarea - describe el contenedor que se va a ejecutar
resource "aws_ecs_task_definition" "app" {
  # Nombre de la familia de la tarea ej: floci-app-dev
  family                   = "${var.project}-app-${var.environment}"
  # Modo de red awsvpc = cada tarea tiene su propia IP dentro de la VPC
  network_mode             = "awsvpc"
  # Tipo de lanzamiento (Fargate = serverless, sin EC2)
  requires_compatibilities = ["FARGATE"]
  # CPU en unidades (256 = 0.25 vCPU, 512 = 0.5 vCPU)
  cpu                      = var.ecs_app_cpu
  # Memoria en MB (512 = 0.5 GB)
  memory                   = var.ecs_app_memory
  # Rol de IAM para que ECS pueda tirar logs, bajar imágenes, etc.
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  # Rol de IAM para que la app pueda usar servicios AWS (SQS, etc.)
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Definición del contenedor en formato JSON
  container_definitions = jsonencode([
    {
      # Nombre del contenedor (debe coincidir con el del load balancer)
      name  = "app"
      # Imagen Docker a usar
      image = var.ecs_app_image
      # Si se cae este contenedor, la tarea se reinicia
      essential = true
      # Mapeo de puertos del contenedor
      portMappings = [
        {
          # Puerto donde la app escucha adentro del contenedor
          containerPort = var.ecs_app_port
          # Mismo puerto en el host (Fargate requiere que sean iguales)
          hostPort      = var.ecs_app_port
          protocol      = "tcp"
        }
      ]
      # Variables de entorno inyectadas al contenedor
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "PORT", value = "3000" },
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_PORT", value = var.db_port },
        { name = "DB_USERNAME", value = var.db_username },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_LOGGING", value = "true" },
      ]
      # Configuración de logs (envía a CloudWatch)
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project}-app-${var.environment}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # Health check que AWS usa para saber si el contenedor está vivo
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.ecs_app_port}/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Environment = var.environment
  }

}

# Servicio ECS - mantiene N tareas corriendo y las registra en el ALB
resource "aws_ecs_service" "app" {
  # Nombre del servicio ej: floci-app-dev
  name            = "${var.project}-app-${var.environment}"
  # Cluster al que pertenece
  cluster         = aws_ecs_cluster.main.id
  # Qué definición de tarea va a ejecutar
  task_definition = aws_ecs_task_definition.app.arn
  # Cantidad de instancias (réplicas) del contenedor
  desired_count       = var.ecs_app_desired_count
  # Tipo de lanzamiento (serverless con Fargate)
  launch_type         = "FARGATE"
  # Estrategia de scheduling (REPLICA = corre N copias idénticas)
  scheduling_strategy = "REPLICA"
  # Versión de la plataforma Fargate (LATEST usa la más reciente)
  platform_version    = "LATEST"

  # Configuración de red del servicio
  network_configuration {
    # Subnets privadas donde se despliegan las tareas
    subnets         = var.private_subnet_ids
    # Security group que controla el tráfico
    security_groups = [var.ecs_security_group_id]
    # No asigna IP pública (están en subnets privadas)
    assign_public_ip = false
  }

  # Balanceador de carga asociado a este servicio
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.ecs_app_port
  }

  # Tiempo de gracia para health check al arrancar (evita matar tareas nuevas)
  health_check_grace_period_seconds = 60

  # Configuración de despliegue (rolling update)
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  tags = {
    Environment = var.environment
  }

}
