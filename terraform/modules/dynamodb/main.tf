locals {
  telemetry_table_name = "${var.project_name}-${var.environment}-telemetry"
  events_table_name    = "${var.project_name}-${var.environment}-events"
}

resource "aws_dynamodb_table" "telemetry" {
  name                        = local.telemetry_table_name
  billing_mode                = var.billing_mode
  hash_key                    = "device_id"
  range_key                   = "record_id"
  deletion_protection_enabled = false

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "effective_ts"
    type = "N"
  }

  global_secondary_index {
    name            = "device_ts_idx"
    hash_key        = "device_id"
    range_key       = "effective_ts"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "events" {
  name                        = local.events_table_name
  billing_mode                = var.billing_mode
  hash_key                    = "device_id"
  range_key                   = "record_id"
  deletion_protection_enabled = false

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "effective_ts"
    type = "N"
  }

  global_secondary_index {
    name            = "device_ts_idx"
    hash_key        = "device_id"
    range_key       = "effective_ts"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}
