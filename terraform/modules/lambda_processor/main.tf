locals {
  function_name = "${var.project_name}-${var.environment}-lambda-processor"
}

data "archive_file" "package" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda_processor.zip"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid    = "WriteToDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]
    resources = [
      var.telemetry_table_arn,
      var.events_table_arn
    ]
  }

  statement {
    sid    = "WriteLambdaLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "lambda_processor" {
  name                  = "${local.function_name}-role"
  assume_role_policy    = data.aws_iam_policy_document.assume_role.json
  force_detach_policies = true
}

resource "aws_iam_role_policy" "lambda_processor" {
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.lambda_processor.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_lambda_function" "lambda_processor" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda_processor.arn
  handler          = "handler.lambda_handler"
  runtime          = var.runtime
  timeout          = var.timeout_seconds
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256

  environment {
    variables = {
      TELEMETRY_TABLE_NAME = var.telemetry_table_name
      EVENTS_TABLE_NAME    = var.events_table_name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_processor]
}
