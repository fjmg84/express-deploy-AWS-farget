# Rol de IAM para que ECS ejecute tareas (bajar imágenes, tirar logs, etc.)
resource "aws_iam_role" "ecs_execution" {
  # Nombre del rol ej: floci-ecs-execution-dev
  name = "${var.project}-ecs-execution-${var.environment}"

  # Política de confianza: solo ECS puede usar este rol
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# Adjunta la política administrada de AWS para ejecución de ECS
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Rol de IAM para las tareas ECS (la app en sí usa este rol)
resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-ecs-task-${var.environment}"

  # Política de confianza: solo ECS puede usar este rol
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# Política personalizada con permisos específicos para la app
resource "aws_iam_policy" "ecs_task" {
  name = "${var.project}-ecs-task-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permisos para usar SQS (colas de mensajes)
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = ["*"]
      },
      {
        # Permisos para escribir logs en CloudWatch
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Adjunta la política personalizada al rol de la tarea
resource "aws_iam_role_policy_attachment" "ecs_task" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_task.arn
}
