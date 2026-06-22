variable "environment" {
  description = "Environment prefix."
  type        = string
}

variable "project_name" {
  description = "Project prefix."
  type        = string
  default     = "esp32-demo"
}

variable "app_name" {
  description = "Amplify app name. Defaults to {project_name}-{environment}-dashboard."
  type        = string
  default     = ""
}

variable "branch_name" {
  description = "Amplify branch name for manual deployments."
  type        = string
  default     = "main"
}

variable "api_base_url" {
  description = "Query API base URL injected at build time."
  type        = string
}

variable "aws_region" {
  description = "AWS region for Amplify deploy API calls."
  type        = string
}

variable "repo_root" {
  description = "Repository root path (for web sources and deploy script)."
  type        = string
}

variable "deploy_amplify_on_apply" {
  description = "Build and deploy web/ to Amplify after apply (avoids the Welcome placeholder page)."
  type        = bool
  default     = true
}
