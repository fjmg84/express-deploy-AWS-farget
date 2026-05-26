output "ecs_log_group" {
  value = aws_cloudwatch_log_group.ecs_app.name
}

output "rds_log_group" {
  value = aws_cloudwatch_log_group.rds.name
}
