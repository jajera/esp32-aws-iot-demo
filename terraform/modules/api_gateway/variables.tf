variable "environment" {
  description = "Environment prefix."
  type        = string
}

variable "project_name" {
  description = "Project prefix."
  type        = string
  default     = "esp32-demo"
}

variable "lambda_query_arn" {
  description = "Query Lambda function ARN."
  type        = string
}

variable "lambda_query_name" {
  description = "Query Lambda function name."
  type        = string
}

variable "cors_allow_origins" {
  description = "Allowed origins for CORS."
  type        = list(string)
  default     = ["*"]
}

variable "stage_name" {
  description = "API stage name."
  type        = string
  default     = "$default"
}
