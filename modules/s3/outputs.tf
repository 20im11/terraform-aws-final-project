output "primary_bucket" {
  value = aws_s3_bucket.primary.id
}

output "replica_bucket" {
  value = aws_s3_bucket.replica.id
}
