output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_address" {
  value = aws_db_instance.postgres.address
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}

output "db_arn" {
  value = aws_db_instance.postgres.arn
}

output "db_instance_identifier" {
  value = aws_db_instance.postgres.identifier
}
