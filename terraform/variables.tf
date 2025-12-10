variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ec2_instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.large"
}

variable "ebs_volume_size" {
  description = "EBS root volume size in GB"
  type        = number
  default     = 10
}

variable "iam_username" {
  description = "IAM user name for application access"
  type        = string
  default     = "app-user"
}

variable "elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP to associate with EC2 instance"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token for cloning private repositories"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_username" {
  description = "GitHub username for credentials in Jenkins"
  type        = string
  default     = ""
}

variable "ec2_key_name" {
  description = "Name of the EC2 keypair to use for SSH access"
  type        = string
  default     = "demo"
}
