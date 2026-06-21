output "backend_api_url" {
  description = "ALB DNS name for the backend API (tier 2)"
  value       = "http://${module.alb.alb_dns}"
}

output "frontend_primary_url" {
  description = "S3 static website endpoint in the primary region (tier 1)"
  value       = "http://${module.s3.primary_website_endpoint}"
}

output "frontend_replica_url" {
  description = "S3 static website endpoint in the secondary region (cross-region replica)"
  value       = "http://${module.s3.replica_website_endpoint}"
}

output "alb_dns" {
  value = module.alb.alb_dns
}
