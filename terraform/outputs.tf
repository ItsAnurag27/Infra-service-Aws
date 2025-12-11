output "vpc_id" {
  description = "VPC ID"
  value       = length(aws_vpc.main) > 0 ? aws_vpc.main[0].id : "Skipped - VPC already exists"
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "EC2 Security Group ID"
  value       = length(aws_security_group.ec2) > 0 ? aws_security_group.ec2[0].id : "Skipped - Security Group already exists"
}

output "security_group_name" {
  description = "EC2 Security Group Name"
  value       = length(aws_security_group.ec2) > 0 ? aws_security_group.ec2[0].name : "Skipped - Security Group already exists"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = length(aws_s3_bucket.app_storage) > 0 ? aws_s3_bucket.app_storage[0].id : "Skipped - S3 bucket already exists"
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = length(aws_s3_bucket.app_storage) > 0 ? aws_s3_bucket.app_storage[0].arn : "Skipped - S3 bucket already exists"
}
output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = length(aws_instance.app) > 0 ? aws_instance.app[*].id : ["Skipped - EIP already associated"]
}

output "ec2_instance_public_ips" {
  description = "EC2 instance public IP addresses"
  value       = length(aws_instance.app) > 0 ? aws_instance.app[*].public_ip : ["Skipped - EIP already associated"]
}

output "ec2_instance_private_ips" {
  description = "EC2 instance private IP addresses"
  value       = length(aws_instance.app) > 0 ? aws_instance.app[*].private_ip : ["Skipped - EIP already associated"]
}

output "iam_user_name" {
  description = "IAM user name"
  value       = length(aws_iam_user.app_user) > 0 ? aws_iam_user.app_user[0].name : "Not available - check AWS console"
}

output "iam_user_arn" {
  description = "IAM user ARN"
  value       = length(aws_iam_user.app_user) > 0 ? aws_iam_user.app_user[0].arn : "Not available - check AWS console"
}

output "iam_access_key_id" {
  description = "IAM user access key ID"
  value       = length(aws_iam_access_key.app_user) > 0 ? aws_iam_access_key.app_user[0].id : "Existing user - check AWS console"
  sensitive   = true
}

output "ec2_names" {
  description = "EC2 instance names"
  value       = aws_instance.app[*].tags.Name
}

output "jenkins_url" {
  description = "Jenkins access URL"
  value       = try("http://${aws_instance.app[0].public_ip}:8080", "Not available")
}

output "jenkins_elastic_ip_url" {
  description = "Jenkins URL using Elastic IP (if configured)"
  value       = "http://44.215.75.53:8080"
}

output "jenkins_credentials" {
  description = "Jenkins default credentials"
  value       = "Username: admin | Password: admin"
  sensitive   = true
}

output "jenkins_github_credentials_id" {
  description = "Jenkins GitHub credentials ID"
  value       = "github-credentials (or use 'github-token' for API token)"
}

output "jenkins_ssh_key_location" {
  description = "Location of SSH private key on EC2 for Jenkins deployment"
  value       = "/var/lib/jenkins/.ssh/jenkins-key"
}

output "jenkins_deployment_note" {
  description = "Important: Update your Docker repo Jenkinsfile with this EC2 IP"
  value       = "Update EC2_IP in Jenkinsfile to: 44.215.75.53 (your Elastic IP)"
}

output "elastic_ip_address" {
  description = "Elastic IP address - NOT USED (using dynamic public IP instead)"
  value       = "Dynamic public IP will be assigned by AWS"
}

output "elastic_ip_allocation_id" {
  description = "Elastic IP allocation ID - NOT USED"
  value       = "Not configured - using dynamic public IP"
}
