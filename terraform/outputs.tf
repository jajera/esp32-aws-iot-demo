output "aws_region" {
  description = "Provisioned AWS region."
  value       = var.aws_region
}

output "environment" {
  description = "Provisioned environment."
  value       = var.environment
}

output "aws_iot_endpoint" {
  description = "IoT Data ATS endpoint for device connectivity."
  value       = data.aws_iot_endpoint.ats.endpoint_address
}

output "telemetry_rule_name" {
  description = "Telemetry rule name."
  value       = module.iot_rule_fanout.telemetry_rule_name
}

output "events_rule_name" {
  description = "Events rule name."
  value       = module.iot_rule_fanout.events_rule_name
}

output "telemetry_rule_arn" {
  description = "Telemetry rule ARN."
  value       = module.iot_rule_fanout.telemetry_rule_arn
}

output "events_rule_arn" {
  description = "Events rule ARN."
  value       = module.iot_rule_fanout.events_rule_arn
}

output "lambda_processor_name" {
  description = "Lambda processor function name."
  value       = module.lambda_processor.function_name
}

output "lambda_processor_arn" {
  description = "Lambda processor function ARN."
  value       = module.lambda_processor.function_arn
}

output "lambda_query_api_name" {
  description = "Query API Lambda function name."
  value       = module.lambda_query_api.function_name
}

output "lambda_query_api_arn" {
  description = "Query API Lambda function ARN."
  value       = module.lambda_query_api.function_arn
}

output "query_api_invoke_url" {
  description = "API Gateway invoke URL for query API."
  value       = module.api_gateway.invoke_url
}

output "telemetry_table_name" {
  description = "Telemetry DynamoDB table name."
  value       = module.dynamodb.telemetry_table_name
}

output "events_table_name" {
  description = "Events DynamoDB table name."
  value       = module.dynamodb.events_table_name
}

output "amplify_app_id" {
  description = "Amplify app ID."
  value       = module.amplify_hosting.app_id
}

output "amplify_app_url" {
  description = "Amplify app URL."
  value       = module.amplify_hosting.app_url
}
