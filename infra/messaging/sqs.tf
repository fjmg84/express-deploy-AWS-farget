# Cola DLQ (Dead Letter Queue) para pedidos - almacena mensajes fallidos
resource "aws_sqs_queue" "orders_dlq" {
  # Nombre de la cola ej: floci-orders-dlq-dev.fifo
  name                       = "${var.project}-orders-dlq-${var.environment}.fifo"
  # FIFO = First In First Out (preserva el orden de los mensajes)
  fifo_queue                 = true
  # Deduplicación automática basada en el contenido del mensaje
  content_based_deduplication = true
  # Tiempo de retención de mensajes (14 días en segundos)
  message_retention_seconds   = 1209600

  tags = {
    Environment = var.environment
  }
}

# Cola principal de pedidos
resource "aws_sqs_queue" "orders" {
  name                        = "${var.project}-orders-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  # Tiempo de espera antes de que el mensaje esté disponible (0 = inmediato)
  delay_seconds               = 0
  # Tamaño máximo del mensaje en bytes (256 KB)
  max_message_size            = 262144
  # Tiempo de retención (4 días en segundos)
  message_retention_seconds   = 345600
  # Tiempo que un consumidor tiene para procesar el mensaje antes de que vuelva a la cola
  visibility_timeout_seconds  = 120
  # Espera activa (long polling) para reducir consultas vacías
  receive_wait_time_seconds   = 10

  # Política de reintentos: después de 3 fallos, manda a la DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
  }
}

# Cola DLQ para notificaciones
resource "aws_sqs_queue" "notifications_dlq" {
  name                       = "${var.project}-notifications-dlq-${var.environment}.fifo"
  fifo_queue                 = true
  content_based_deduplication = true
  message_retention_seconds   = 1209600

  tags = {
    Environment = var.environment
  }
}

# Cola principal de notificaciones
resource "aws_sqs_queue" "notifications" {
  name                        = "${var.project}-notifications-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  delay_seconds               = 0
  max_message_size            = 262144
  message_retention_seconds   = 345600
  visibility_timeout_seconds  = 60
  receive_wait_time_seconds   = 10

  # Después de 3 intentos fallidos, pasa a la DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
  }
}
