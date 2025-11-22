output "primary_bucket" {
  description = "Primary S3 bucket name"
  value       = aws_s3_bucket.primary.id
}

output "secondary_bucket" {
  description = "Secondary (DR) S3 bucket name"
  value       = aws_s3_bucket.secondary.id
}

output "health_check_id" {
  description = "Route53 health check ID"
  value       = aws_route53_health_check.primary.id
}

output "dr_alerts_topic" {
  description = "SNS topic for DR alerts"
  value       = aws_sns_topic.dr_alerts.arn
}

output "replication_status" {
  description = "S3 replication configuration"
  value       = "Primary (eu-west-2) -> Secondary (eu-west-1)"
}
