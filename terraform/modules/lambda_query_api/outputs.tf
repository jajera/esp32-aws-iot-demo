output "function_arn" {
  description = "Query Lambda function ARN."
  value       = aws_lambda_function.lambda_query.arn
}

output "function_name" {
  description = "Query Lambda function name."
  value       = aws_lambda_function.lambda_query.function_name
}

output "invoke_role_arn" {
  description = "Query Lambda execution role ARN."
  value       = aws_iam_role.lambda_query.arn
}
