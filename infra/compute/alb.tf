# Application Load Balancer - distribuye tráfico entre las tareas ECS
resource "aws_lb" "app" {
  # Nombre del ALB ej: floci-alb-dev
  name               = "${var.project}-alb-${var.environment}"
  # false = ALB público (accesible desde internet), true = interno
  internal           = false
  # Tipo de balanceador (application = HTTP/HTTPS)
  load_balancer_type = "application"
  # Security groups que controlan el tráfico hacia el ALB
  security_groups    = [var.alb_security_group_id]
  # Subnets públicas donde se despliega el ALB
  subnets            = var.public_subnet_ids

  # Tiempo máximo de inactividad antes de cerrar la conexión
  idle_timeout = 60

  tags = {
    Environment = var.environment
  }
}

# Target group - grupo de destinos (tareas ECS) a los que el ALB envía tráfico
resource "aws_lb_target_group" "app" {
  # Nombre del target group ej: floci-tg-dev
  name        = "${var.project}-tg-${var.environment}"
  # Puerto al que el ALB envía el tráfico
  port        = var.ecs_app_port
  protocol    = "HTTP"
  # ip = las tareas ECS se identifican por IP (no por ID de instancia)
  target_type = "ip"
  # VPC donde está el target group
  vpc_id      = var.vpc_id

  # Health check - verifica que las tareas estén vivas antes de mandarles tráfico
  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Tiempo de espera antes de desconectar una tarea que se da de baja
  deregistration_delay = 30

  tags = {
    Environment = var.environment
  }
}

# Listener HTTP (puerto 80) - escucha tráfico entrante y lo reenvía al target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Listener HTTPS (puerto 443) - solo se crea en producción
resource "aws_lb_listener" "https" {
  count             = var.environment == "prod" ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
