locals {
  telemetry_log_group_name = "/aws/iot/${var.project_name}/telemetry"
  events_log_group_name    = "/aws/iot/${var.project_name}/events"
  errors_log_group_name    = "/aws/iot/${var.project_name}/errors"
}

resource "aws_cloudwatch_log_group" "telemetry" {
  name              = local.telemetry_log_group_name
  retention_in_days = 1
  skip_destroy      = false
}

resource "aws_cloudwatch_log_group" "events" {
  name              = local.events_log_group_name
  retention_in_days = 1
  skip_destroy      = false
}

resource "aws_cloudwatch_log_group" "errors" {
  name              = local.errors_log_group_name
  retention_in_days = 1
  skip_destroy      = false
}

module "dynamodb" {
  source = "./modules/dynamodb"

  environment  = var.environment
  project_name = var.project_name
  billing_mode = var.billing_mode
}

module "lambda_processor" {
  source = "./modules/lambda_processor"

  environment          = var.environment
  telemetry_table_name = module.dynamodb.telemetry_table_name
  telemetry_table_arn  = module.dynamodb.telemetry_table_arn
  events_table_name    = module.dynamodb.events_table_name
  events_table_arn     = module.dynamodb.events_table_arn
}

module "iot_rule_fanout" {
  source = "./modules/iot_rule_fanout"

  telemetry_topic_pattern = var.telemetry_topic_pattern
  events_topic_pattern    = var.events_topic_pattern

  cloudwatch_telemetry_arn            = aws_cloudwatch_log_group.telemetry.arn
  cloudwatch_events_arn               = aws_cloudwatch_log_group.events.arn
  cloudwatch_error_arn                = aws_cloudwatch_log_group.errors.arn
  cloudwatch_telemetry_log_group_name = aws_cloudwatch_log_group.telemetry.name
  cloudwatch_events_log_group_name    = aws_cloudwatch_log_group.events.name
  cloudwatch_error_log_group_name     = aws_cloudwatch_log_group.errors.name
  lambda_processor_arn                = module.lambda_processor.function_arn

  depends_on = [
    aws_cloudwatch_log_group.telemetry,
    aws_cloudwatch_log_group.events,
    aws_cloudwatch_log_group.errors
  ]
}

module "lambda_query_api" {
  source = "./modules/lambda_query_api"

  environment          = var.environment
  telemetry_table_name = module.dynamodb.telemetry_table_name
  telemetry_table_arn  = module.dynamodb.telemetry_table_arn
  events_table_name    = module.dynamodb.events_table_name
  events_table_arn     = module.dynamodb.events_table_arn
}

module "api_gateway" {
  source = "./modules/api_gateway"

  environment        = var.environment
  lambda_query_arn   = module.lambda_query_api.function_arn
  lambda_query_name  = module.lambda_query_api.function_name
  cors_allow_origins = var.cors_allow_origins
  stage_name         = var.api_stage_name
}

module "amplify_hosting" {
  source = "./modules/amplify_hosting"

  environment             = var.environment
  project_name            = var.project_name
  api_base_url            = module.api_gateway.invoke_url
  aws_region              = var.aws_region
  repo_root               = abspath("${path.module}/..")
  deploy_amplify_on_apply = var.deploy_amplify_on_apply
  app_name                = var.amplify_app_name

  depends_on = [module.api_gateway]
}

data "aws_iot_endpoint" "ats" {
  endpoint_type = "iot:Data-ATS"
}
