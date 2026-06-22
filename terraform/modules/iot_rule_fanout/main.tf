data "aws_iam_policy_document" "iot_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "iot_rule_role_policy" {
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${var.cloudwatch_telemetry_arn}:*",
      "${var.cloudwatch_events_arn}:*",
      "${var.cloudwatch_error_arn}:*"
    ]
  }

  statement {
    sid    = "LambdaInvoke"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      var.lambda_processor_arn
    ]
  }
}

resource "aws_iam_role" "iot_rule_role" {
  name                  = var.cloudwatch_role_name
  assume_role_policy    = data.aws_iam_policy_document.iot_assume_role.json
  force_detach_policies = true
}

resource "aws_iam_role_policy" "iot_rule_role" {
  name   = var.cloudwatch_role_policy_name
  role   = aws_iam_role.iot_rule_role.id
  policy = data.aws_iam_policy_document.iot_rule_role_policy.json
}

resource "aws_iot_topic_rule" "telemetry" {
  name        = var.telemetry_rule_name
  enabled     = true
  sql         = "SELECT * FROM '${var.telemetry_topic_pattern}'"
  sql_version = "2016-03-23"

  cloudwatch_logs {
    log_group_name = var.cloudwatch_telemetry_log_group_name
    role_arn       = aws_iam_role.iot_rule_role.arn
  }

  lambda {
    function_arn = var.lambda_processor_arn
  }

  error_action {
    cloudwatch_logs {
      log_group_name = var.cloudwatch_error_log_group_name
      role_arn       = aws_iam_role.iot_rule_role.arn
    }
  }

  depends_on = [aws_iam_role_policy.iot_rule_role]
}

resource "aws_iot_topic_rule" "events" {
  name        = var.events_rule_name
  enabled     = true
  sql         = "SELECT * FROM '${var.events_topic_pattern}'"
  sql_version = "2016-03-23"

  cloudwatch_logs {
    log_group_name = var.cloudwatch_events_log_group_name
    role_arn       = aws_iam_role.iot_rule_role.arn
  }

  lambda {
    function_arn = var.lambda_processor_arn
  }

  error_action {
    cloudwatch_logs {
      log_group_name = var.cloudwatch_error_log_group_name
      role_arn       = aws_iam_role.iot_rule_role.arn
    }
  }

  depends_on = [aws_iam_role_policy.iot_rule_role]
}

resource "aws_lambda_permission" "from_telemetry_rule" {
  statement_id  = "AllowExecutionFromIotTelemetryRule"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_processor_arn
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.telemetry.arn
}

resource "aws_lambda_permission" "from_events_rule" {
  statement_id  = "AllowExecutionFromIotEventsRule"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_processor_arn
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.events.arn
}
