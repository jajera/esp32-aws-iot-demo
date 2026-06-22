output "telemetry_rule_name" {
  description = "Telemetry rule name."
  value       = aws_iot_topic_rule.telemetry.name
}

output "events_rule_name" {
  description = "Events rule name."
  value       = aws_iot_topic_rule.events.name
}

output "telemetry_rule_arn" {
  description = "Telemetry rule ARN."
  value       = aws_iot_topic_rule.telemetry.arn
}

output "events_rule_arn" {
  description = "Events rule ARN."
  value       = aws_iot_topic_rule.events.arn
}
