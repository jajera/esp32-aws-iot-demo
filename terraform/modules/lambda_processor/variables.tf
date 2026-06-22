variable "environment" {
  description = "Environment prefix."
  type        = string
}

variable "project_name" {
  description = "Project prefix."
  type        = string
  default     = "esp32-demo"
}

variable "telemetry_table_name" {
  description = "Telemetry DynamoDB table name."
  type        = string
}

variable "telemetry_table_arn" {
  description = "Telemetry DynamoDB table ARN."
  type        = string
}

variable "events_table_name" {
  description = "Events DynamoDB table name."
  type        = string
}

variable "events_table_arn" {
  description = "Events DynamoDB table ARN."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.11"
}

variable "timeout_seconds" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}
