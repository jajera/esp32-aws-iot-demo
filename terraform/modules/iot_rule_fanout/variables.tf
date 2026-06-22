variable "telemetry_topic_pattern" {
  description = "Telemetry MQTT topic pattern (without SQL wrapper)."
  type        = string
}

variable "events_topic_pattern" {
  description = "Events MQTT topic pattern (without SQL wrapper)."
  type        = string
}

variable "cloudwatch_telemetry_arn" {
  description = "Telemetry CloudWatch log group ARN."
  type        = string
}

variable "cloudwatch_events_arn" {
  description = "Events CloudWatch log group ARN."
  type        = string
}

variable "cloudwatch_error_arn" {
  description = "Error CloudWatch log group ARN."
  type        = string
}

variable "cloudwatch_telemetry_log_group_name" {
  description = "Telemetry CloudWatch log group name."
  type        = string
}

variable "cloudwatch_events_log_group_name" {
  description = "Events CloudWatch log group name."
  type        = string
}

variable "cloudwatch_error_log_group_name" {
  description = "Error CloudWatch log group name."
  type        = string
}

variable "lambda_processor_arn" {
  description = "Lambda processor function ARN."
  type        = string
}

variable "cloudwatch_role_name" {
  description = "IAM role assumed by IoT rules."
  type        = string
  default     = "esp32-demo-iot-rule-role"
}

variable "cloudwatch_role_policy_name" {
  description = "Inline IAM policy name used by IoT rules role."
  type        = string
  default     = "esp32-demo-iot-rule-logs"
}

variable "telemetry_rule_name" {
  description = "Telemetry topic rule name."
  type        = string
  default     = "esp32_demo_telemetry_rule"
}

variable "events_rule_name" {
  description = "Events topic rule name."
  type        = string
  default     = "esp32_demo_events_rule"
}
