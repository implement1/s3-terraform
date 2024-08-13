# ---------------------------------------------------------------------------------------------------------------------
# PIN TERRAFORM VERSION TO >= 0.12
# The examples have been upgraded to 0.12 syntax
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 0.12.26"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.16.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A S3 BUCKET WITH VERSIONING ENABLED INCLUDING TAGS
# ---------------------------------------------------------------------------------------------------------------------

# Deploy and configure test S3 bucket with versioning and access log
resource "aws_s3_bucket" "test_bucket" {
  bucket = "${local.aws_account_id}-${var.tag_bucket_name}"

  tags = {
    Name        = var.tag_bucket_name
    Environment = var.tag_bucket_environment
  }
}

resource "aws_s3_bucket_logging" "test_bucket" {
  bucket        = aws_s3_bucket.test_bucket.id
  target_bucket = aws_s3_bucket.test_bucket_logs.id
  target_prefix = "TFStateLogs/"
}

resource "aws_s3_bucket_versioning" "test_bucket" {
  bucket = aws_s3_bucket.test_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "test_bucket" {
  bucket = aws_s3_bucket.test_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
  depends_on = [aws_s3_bucket.test_bucket]
}

resource "aws_s3_bucket_acl" "test_bucket" {
  bucket     = aws_s3_bucket.test_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.test_bucket]
}


# Deploy S3 bucket to collect access logs for test bucket
resource "aws_s3_bucket" "test_bucket_logs" {
  bucket = "${local.aws_account_id}-${var.tag_bucket_name}-logs"

  tags = {
    Name        = "${local.aws_account_id}-${var.tag_bucket_name}-logs"
    Environment = var.tag_bucket_environment
  }

  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "test_bucket_logs" {
  bucket = aws_s3_bucket.test_bucket_logs.id
  rule {
    object_ownership = "ObjectWriter"
  }
  depends_on = [aws_s3_bucket.test_bucket_logs]
}

resource "aws_s3_bucket_acl" "test_bucket_logs" {
  bucket     = aws_s3_bucket.test_bucket_logs.id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.test_bucket_logs]
}

# Configure bucket access policies

resource "aws_s3_bucket_policy" "bucket_access_policy" {
  count  = var.with_policy ? 1 : 0
  bucket = aws_s3_bucket.test_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = [local.aws_account_id]
      type        = "AWS"
    }
    actions   = ["*"]
    resources = ["${aws_s3_bucket.test_bucket.arn}/*"]
  }

  statement {
    effect = "Deny"
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    actions   = ["*"]
    resources = ["${aws_s3_bucket.test_bucket.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false",
      ]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LOCALS
# Used to represent any data that requires complex expressions/interpolations
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {
}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}

