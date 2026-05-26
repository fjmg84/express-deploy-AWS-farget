# Firewall del ALB (Application Load Balancer) - controla tráfico hacia el balanceador
resource "aws_security_group" "alb" {
  # Nombre único ej: floci-alb-sg-dev
  name        = "${var.project}-alb-sg-${var.environment}"
  # Descripción visible en AWS
  description = "Security Group para ALB"
  # VPC a la que pertenece
  vpc_id      = aws_vpc.main.id

  # Regla de entrada: permite tráfico HTTP (puerto 80) desde cualquier IP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de entrada: permite tráfico HTTPS (puerto 443) desde cualquier IP
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de salida: permite todo el tráfico saliente (protocolo -1 = todos)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-alb-sg-${var.environment}"
    Environment = var.environment
  }
}

# Firewall de ECS - controla tráfico hacia las tareas del contenedor
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg-${var.environment}"
  description = "Security Group para ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Regla de entrada: solo permite tráfico proveniente del ALB (por ID del SG del ALB)
  ingress {
    description     = "Traffic from ALB"
    from_port       = var.ecs_app_port
    to_port         = var.ecs_app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Regla de salida: permite todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-ecs-sg-${var.environment}"
    Environment = var.environment
  }
}

# Firewall de RDS - controla tráfico hacia la base de datos
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg-${var.environment}"
  description = "Security Group para RDS"
  vpc_id      = aws_vpc.main.id

  # Regla de entrada: solo permite PostgreSQL (puerto 5432) desde ECS
  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Regla de salida: permite todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-rds-sg-${var.environment}"
    Environment = var.environment
  }
}
