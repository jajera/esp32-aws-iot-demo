locals {
  app_name = var.app_name != "" ? var.app_name : "${var.project_name}-${var.environment}-dashboard"
}

resource "aws_amplify_app" "dashboard" {
  name     = local.app_name
  platform = "WEB"

  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - cd web && npm ci
        build:
          commands:
            - cd web && npm run build
      artifacts:
        baseDirectory: web/dist
        files:
          - '**/*'
      cache:
        paths:
          - web/node_modules/**/*
  EOT

  environment_variables = {
    VITE_API_URL = var.api_base_url
  }
}

resource "aws_amplify_branch" "dashboard" {
  app_id      = aws_amplify_app.dashboard.id
  branch_name = var.branch_name
}
