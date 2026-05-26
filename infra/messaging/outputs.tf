output "orders_queue_url" {
  value = aws_sqs_queue.orders.url
}

output "orders_queue_arn" {
  value = aws_sqs_queue.orders.arn
}

output "orders_dlq_arn" {
  value = aws_sqs_queue.orders_dlq.arn
}

output "notifications_queue_url" {
  value = aws_sqs_queue.notifications.url
}

output "notifications_queue_arn" {
  value = aws_sqs_queue.notifications.arn
}
