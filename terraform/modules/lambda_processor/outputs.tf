output "function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.lambda_processor.arn
}

output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.lambda_processor.function_name
}

output "invoke_role_arn" {
  description = "Lambda execution role ARN."
  value       = aws_iam_role.lambda_processor.arn
}
