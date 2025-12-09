output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "EC2 Security Group ID"
  value       = aws_security_group.ec2.id
}

output "security_group_name" {
  description = "EC2 Security Group Name"
  value       = aws_security_group.ec2.name
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_storage.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.app_storage.arn
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.app[*].id
}

output "ec2_instance_public_ips" {
  description = "EC2 instance public IP addresses"
  value       = aws_instance.app[*].public_ip
}

output "ec2_instance_private_ips" {
  description = "EC2 instance private IP addresses"
  value       = aws_instance.app[*].private_ip
}

output "iam_user_name" {
  description = "IAM user name"
  value       = aws_iam_user.app_user.name
}

output "iam_user_arn" {
  description = "IAM user ARN"
  value       = aws_iam_user.app_user.arn
}

output "iam_access_key_id" {
  description = "IAM user access key ID"
  value       = aws_iam_access_key.app_user.id
  sensitive   = true
}
