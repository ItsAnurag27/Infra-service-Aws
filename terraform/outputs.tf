output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = aws_rds_instance.postgres.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_rds_instance.postgres.db_name
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_storage.id
}

output "elasticache_endpoint" {
  description = "ElastiCache cluster endpoint"
  value       = "N/A - ElastiCache removed"
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.app[*].id
}

output "ec2_private_ips" {
  description = "EC2 instance private IP addresses"
  value       = aws_instance.app[*].private_ip
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.app.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.app.name
}
