terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.secondary]
    }
  }
}

resource "aws_s3_bucket" "primary" {
  bucket = "${var.project_name}-primary-fin-proj3230"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.secondary
  bucket   = "${var.project_name}-replica-fin-proj3230"
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}
