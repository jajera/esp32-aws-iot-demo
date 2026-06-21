resource "aws_apigatewayv2_api" "query_api" {
  name          = "${var.project_name}-${var.environment}-query-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET", "OPTIONS"]
    allow_origins = var.cors_allow_origins
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda_query" {
  api_id                 = aws_apigatewayv2_api.query_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.lambda_query_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "latest_telemetry" {
  api_id    = aws_apigatewayv2_api.query_api.id
  route_key = "GET /devices/{deviceId}/telemetry/latest"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_query.id}"
}

resource "aws_apigatewayv2_route" "recent_events" {
  api_id    = aws_apigatewayv2_api.query_api.id
  route_key = "GET /devices/{deviceId}/events"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_query.id}"
}

resource "aws_apigatewayv2_stage" "query_api" {
  api_id      = aws_apigatewayv2_api.query_api.id
  name        = var.stage_name
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_query_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.query_api.execution_arn}/*/*"
}
