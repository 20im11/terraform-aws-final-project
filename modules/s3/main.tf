terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.secondary]
    }
  }
}

############################################
# Buckets (primary region + replica region)
############################################

resource "aws_s3_bucket" "primary" {
  bucket = "${var.project_name}-primary-fin-proj3230"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.secondary
  bucket   = "${var.project_name}-replica-fin-proj3230"
}

############################################
# Versioning (required for replication)
############################################

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

############################################
# Static website hosting
############################################

resource "aws_s3_bucket_website_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_website_configuration" "replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.replica.id
  index_document {
    suffix = "index.html"
  }
}

############################################
# Public read access (for static website)
############################################

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "public_read_primary" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.primary.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "public_read_replica" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.replica.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "primary" {
  bucket     = aws_s3_bucket.primary.id
  policy     = data.aws_iam_policy_document.public_read_primary.json
  depends_on = [aws_s3_bucket_public_access_block.primary]
}

resource "aws_s3_bucket_policy" "replica" {
  provider   = aws.secondary
  bucket     = aws_s3_bucket.replica.id
  policy     = data.aws_iam_policy_document.public_read_replica.json
  depends_on = [aws_s3_bucket_public_access_block.replica]
}

############################################
# Frontend content
# Uploaded to both buckets so each region's
# website works immediately; replication keeps
# future changes in sync (primary -> replica).
############################################

resource "aws_s3_object" "index_primary" {
  bucket       = aws_s3_bucket.primary.id
  key          = "index.html"
  source       = "${path.root}/frontend/index.html"
  etag         = filemd5("${path.root}/frontend/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "index_replica" {
  provider     = aws.secondary
  bucket       = aws_s3_bucket.replica.id
  key          = "index.html"
  source       = "${path.root}/frontend/index.html"
  etag         = filemd5("${path.root}/frontend/index.html")
  content_type = "text/html"
}

############################################
# Cross-region replication (primary -> replica)
############################################

data "aws_iam_policy_document" "replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  name               = "${var.project_name}-s3-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.primary.arn]
  }
  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.primary.arn}/*"]
  }
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${aws_s3_bucket.replica.arn}/*"]
  }
}

resource "aws_iam_role_policy" "replication" {
  name   = "${var.project_name}-s3-replication"
  role   = aws_iam_role.replication.id
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_s3_bucket_replication_configuration" "this" {
  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.replica,
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
  }
}
