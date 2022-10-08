####################################
# S3 Storage buckets
####################################
resource "aws_kms_key" "encryption-key" {
  description             = "This key is used to encrypt datalake S3 bucket"
  deletion_window_in_days = var.kms_key_deletion_window
}

resource "aws_s3_bucket" "storage_buckets" {
  for_each = var.storage_buckets
  bucket   = "${var.storage_buckets_prefix}-each.value-${var.storage_buckets_suffix}"

  tags = merge({
  }, var.tags)
}

resource "aws_s3_bucket_acl" "storage_buckets_acl" {
  for_each = var.storage_buckets
  bucket   = aws_s3_bucket.storage_buckets.id
  acl      = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3-encryption" {
  for_each = var.storage_buckets
  bucket   = aws_s3_bucket.storage_buckets.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.encryption-key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "s3-versioning" {
  for_each = var.storage_buckets
  bucket   = aws_s3_bucket.storage_buckets.id
  versioning_configuration {
    status = var.bronze_s3_versioning
  }
}

resource "aws_s3_bucket_public_access_block" "access-policy" {
  bucket = aws_s3_bucket.storage_buckets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

####################################
# Airflow Bucket
####################################
resource "aws_s3_bucket" "mwaa" {
  bucket = var.airflow_bucket_name
}

resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mwaa" {
  bucket                  = aws_s3_bucket.mwaa.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

####################################
# Airflow
####################################
resource "aws_mwaa_environment" "this" {
  airflow_configuration_options = var.airflow_configuration_options

  execution_role_arn = aws_iam_role.this.arn
  name               = var.environment_name
  max_workers        = var.max_workers
  min_workers        = var.min_workers
  environment_class  = var.environment_class
  airflow_version    = var.airflow_version

  source_bucket_arn              = var.source_bucket_arn
  dag_s3_path                    = var.dag_s3_path
  plugins_s3_path                = var.plugins_s3_path
  plugins_s3_object_version      = var.plugins_s3_object_version
  requirements_s3_path           = var.requirements_s3_path
  requirements_s3_object_version = var.requirements_s3_object_version

  logging_configuration {
    dag_processing_logs {
      enabled   = var.dag_processing_logs_enabled
      log_level = var.dag_processing_logs_level
    }

    scheduler_logs {
      enabled   = var.scheduler_logs_enabled
      log_level = var.scheduler_logs_level
    }

    task_logs {
      enabled   = var.task_logs_enabled
      log_level = var.task_logs_level
    }

    webserver_logs {
      enabled   = var.webserver_logs_enabled
      log_level = var.webserver_logs_level
    }

    worker_logs {
      enabled   = var.worker_logs_enabled
      log_level = var.worker_logs_level
    }
  }

  network_configuration {
    security_group_ids = concat([aws_security_group.this.id], var.additional_associated_security_group_ids)
    subnet_ids         = var.create_networking_config ? aws_subnet.private[*].id : var.private_subnet_ids
  }

  webserver_access_mode           = var.webserver_access_mode
  weekly_maintenance_window_start = var.weekly_maintenance_window_start

  kms_key = var.kms_key_arn

  tags = merge({
    Name = "mwaa-${var.environment_name}"
  }, var.tags)
}
