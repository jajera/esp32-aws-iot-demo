variable "environment" {
  description = "Environment prefix for table names."
  type        = string
}

variable "project_name" {
  description = "Project prefix used in table names."
  type        = string
  default     = "esp32-demo"
}

variable "billing_mode" {
  description = "DynamoDB billing mode."
  type        = string
  default     = "PAY_PER_REQUEST"
}
