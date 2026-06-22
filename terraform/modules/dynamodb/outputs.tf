output "telemetry_table_name" {
  description = "Telemetry table name."
  value       = aws_dynamodb_table.telemetry.name
}

output "telemetry_table_arn" {
  description = "Telemetry table ARN."
  value       = aws_dynamodb_table.telemetry.arn
}

output "events_table_name" {
  description = "Events table name."
  value       = aws_dynamodb_table.events.name
}

output "events_table_arn" {
  description = "Events table ARN."
  value       = aws_dynamodb_table.events.arn
}
