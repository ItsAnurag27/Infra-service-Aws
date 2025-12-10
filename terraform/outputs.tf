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

output "ec2_elastic_ip_association" {
  description = "Elastic IP association with EC2 instance"
  value       = try(aws_eip_association.app[0].id, "Not associated")
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
  description = "Elastic IP address associated with EC2 instance"
  value       = "44.215.75.53"
}

output "elastic_ip_allocation_id" {
  description = "Elastic IP allocation ID"
  value       = var.elastic_ip_allocation_id
}
