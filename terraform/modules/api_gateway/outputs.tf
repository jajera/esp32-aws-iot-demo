output "api_id" {
  description = "API Gateway ID."
  value       = aws_apigatewayv2_api.query_api.id
}

output "invoke_url" {
  description = "API invoke URL."
  value       = aws_apigatewayv2_stage.query_api.invoke_url
}

output "stage_name" {
  description = "API stage name."
  value       = aws_apigatewayv2_stage.query_api.name
}
