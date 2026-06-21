variable "environment" {
  description = "Environment name (for example: dev)."
  type        = string
}

variable "aws_region" {
  description = "AWS region for shared infrastructure."
  type        = string
}

variable "project_name" {
  description = "Project prefix used in resource naming."
  type        = string
  default     = "esp32-demo"
}

variable "billing_mode" {
  description = "DynamoDB billing mode."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "telemetry_topic_pattern" {
  description = "Stable telemetry SQL topic pattern."
  type        = string
  default     = "devices/+/telemetry"
}

variable "events_topic_pattern" {
  description = "Stable events SQL topic pattern."
  type        = string
  default     = "devices/+/events"
}

variable "cors_allow_origins" {
  description = "CORS allowed origins for Query API."
  type        = list(string)
  default     = ["*"]
}

variable "api_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "$default"
}

variable "deploy_amplify_on_apply" {
  description = "Build and deploy web/ to Amplify after apply (avoids the default Welcome page)."
  type        = bool
  default     = true
}

variable "amplify_app_name" {
  description = "Amplify application name. Leave empty to use {project_name}-{environment}-dashboard."
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "Additional tags merged with defaults."
  type        = map(string)
  default     = {}
}
