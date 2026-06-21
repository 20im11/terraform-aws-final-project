output "primary_bucket" {
  value = aws_s3_bucket.primary.id
}

output "replica_bucket" {
  value = aws_s3_bucket.replica.id
}

output "primary_website_endpoint" {
  value = aws_s3_bucket_website_configuration.primary.website_endpoint
}

output "replica_website_endpoint" {
  value = aws_s3_bucket_website_configuration.replica.website_endpoint
}
