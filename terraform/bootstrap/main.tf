# Intentionally on local state, so it avoids the chicken and egg solution - storing TFstate in a bucket, but wanting to create the bucket with TF as well

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "aws-learning"
}

# to get the account ID to be used in S3 bucket name
data "aws_caller_identity" "current" {}

# Create the S3 bucket for tfstate
resource "aws_s3_bucket" "tf_state" {
  bucket = "from-k8s-to-aws-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for the tfstate lock
resource "aws_dynamodb_table" "tf_lock" {
  name = "from-k8s-to-aws-tf-lock"
  # costs nothing while idle
  billing_mode = "PAY_PER_REQUEST"
  # TF S3 backend looks specifically for attribute with this name
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}