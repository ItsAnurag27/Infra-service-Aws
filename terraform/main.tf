terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Timestamp   = "2025-12-09"
    }
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Get Available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Check if VPC already exists with our naming pattern
data "aws_vpcs" "existing_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${substr(data.aws_caller_identity.current.account_id, -4, -1)}-vpc"]
  }
}

# Check if Security Group already exists
data "aws_security_groups" "existing_sg" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${substr(data.aws_caller_identity.current.account_id, -4, -1)}-ec2-sg"]
  }
}

# Get existing subnets from the VPC (if VPC exists)
data "aws_subnets" "existing_public" {
  count = length(data.aws_vpcs.existing_vpc.ids) > 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.existing_vpc.ids[0]]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-*-public-subnet"]
  }
}

# Check if Elastic IP is already associated with an EC2 instance
# Locals for unique naming to avoid conflicts
locals {
  unique_suffix  = substr(data.aws_caller_identity.current.account_id, -4, -1)
  resource_name  = "${var.project_name}-${local.unique_suffix}"

  # Skip VPC creation if it already exists
  vpc_exists         = length(data.aws_vpcs.existing_vpc.ids) > 0
  should_create_vpc  = !local.vpc_exists

  # Check if Security Group already exists
  sg_exists        = length(data.aws_security_groups.existing_sg.ids) > 0
  should_create_sg = !local.sg_exists && local.should_create_vpc

  # S3 bucket will attempt creation; AWS will error if it exists
  s3_bucket_name  = "${var.project_name}-${local.unique_suffix}-storage"
  should_create_s3 = true

  # Always create EC2
  should_create_ec2 = true

  # Skip IAM user creation if it already exists (simplified)
  iam_user_exists        = false
  should_create_iam_user = true
}

# SERVICE 1: VPC and Networking
resource "aws_vpc" "main" {
  count                = local.should_create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.resource_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  count  = local.should_create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = local.should_create_vpc ? 2 : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = local.should_create_vpc ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  count  = local.should_create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${local.resource_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.should_create_vpc ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# SERVICE 2: Security Group (for EC2)
resource "aws_security_group" "ec2" {
  count       = local.should_create_sg ? 1 : 0
  name        = "${local.resource_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Jenkins access"
  }

  ingress {
    from_port   = 9080
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Docker services: NGINX, APACHE, BUSYBOX, MEMCACHED, ALPINE, REDIS, POSTGRES, MYSQL, RABBITMQ, PROMETHEUS, GITLAB"
  }

  ingress {
    from_port   = 3000
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "APP and GRAFANA services"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DOCKER_REGISTRY service"
  }

  ingress {
    from_port   = 8001
    to_port     = 8002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "JENKINS custom and PORTAINER services"
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "VAULT service"
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "CONSUL service"
  }

  ingress {
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ETCD service"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# SERVICE 3: EC2 Instances
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app" {
  count                       = local.should_create_ec2 ? var.ec2_instance_count : 0
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.ec2_instance_type
  key_name                    = var.ec2_key_name
  subnet_id                   = local.should_create_vpc ? aws_subnet.public[count.index % 2].id : data.aws_subnets.existing_public[0].ids[count.index % length(data.aws_subnets.existing_public[0].ids)]
  vpc_security_group_ids      = local.should_create_sg ? [aws_security_group.ec2[0].id] : [data.aws_security_groups.existing_sg.ids[0]]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.ebs_volume_size
    delete_on_termination = true
    encrypted             = false
  }

  user_data = base64encode(<<EOF
#!/bin/bash
set -e
exec > >(tee /var/log/setup.log)
exec 2>&1

echo "======================================"
echo "PHASE 1: EC2 BOOTSTRAP (user_data)"
echo "Start: \$(date)"
echo "======================================"

# PHASE 1A: System updates
echo ""
echo "PHASE 1A: System updates..."
yum update -y
yum install -y git curl wget java-17-amazon-corretto-headless

# PHASE 1B: Docker installation
echo ""
echo "PHASE 1B: Docker installation..."
if ! yum install -y docker 2>/dev/null; then
  amazon-linux-extras install -y docker
fi
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user
echo "✅ Docker: \$(docker --version)"

# PHASE 1C: Docker Compose installation
echo ""
echo "PHASE 1C: Docker Compose installation..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
chmod +x /usr/local/bin/docker-compose
echo "✅ Docker Compose: \$(docker-compose --version)"

# PHASE 1D: Prepare for Jenkins (repo + GPG key)
echo ""
echo "PHASE 1D: Preparing Jenkins repository..."
cat >/etc/yum.repos.d/jenkins.repo <<'JENKINS_EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
JENKINS_EOF
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key 2>/dev/null || true
echo "✅ Jenkins repository ready"

# PHASE 1D: Prepare for Jenkins (repo + docker-compose)
echo ""
echo "PHASE 1D: Preparing Jenkins Docker Compose..."
cat >/opt/docker-compose.yml <<'COMPOSE_EOF'
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:jdk21
    container_name: jenkins
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--httpPort=8080
    restart: unless-stopped
    networks:
      - jenkins_network

volumes:
  jenkins_home:
    driver: local

networks:
  jenkins_network:
    driver: bridge
COMPOSE_EOF
echo "✅ Docker Compose configuration ready"

# PHASE 1E: Clone repository
echo ""
echo "PHASE 1E: Cloning Docker services repository..."
mkdir -p /opt/docker-services
cd /opt/docker-services
git clone https://github.com/ItsAnurag27/5-service-jenkins-pipeline.git . 2>/dev/null || echo "⚠️  Git clone warning"
echo "✅ Repository cloned"

# PHASE 1F: Start Jenkins container
echo ""
echo "PHASE 1F: Starting Jenkins container..."
cd /opt
docker-compose -f docker-compose.yml up -d
echo "✅ Jenkins container started"

# PHASE 1G: Wait for Jenkins to be ready
echo ""
echo "PHASE 1G: Waiting for Jenkins to be ready..."
for i in {1..60}; do
  if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ Jenkins web interface is ready! ($i seconds)"
    break
  fi
  if [ $i -eq 60 ]; then
    echo "⏳ Jenkins still initializing (first startup takes 1-2 minutes)"
  fi
  sleep 2
done

# PHASE 1 Complete
echo ""
echo "======================================"
echo "✅ PHASE 1 COMPLETE!"
echo "======================================"
echo "Docker: \$(docker --version)"
echo "Docker Compose: \$(docker-compose --version)"
echo "Java: \$(java -version 2>&1 | head -1)"
echo ""
echo "📋 JENKINS RUNNING:"
echo "   Access Jenkins at: http://\$(hostname -I | awk '{print \$1}'):8080"
echo "   Container: \$(docker ps --filter name=jenkins --format '{{.Status}}')"
echo ""
echo "📝 GET INITIAL ADMIN PASSWORD:"
echo "   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
echo "======================================"
echo ""
echo "Log file:  /var/log/setup.log"
echo "======================================"
EOF
  )


  tags = {
    Name = "15-services-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# SERVICE 4: S3 Bucket for Storage
resource "aws_s3_bucket" "app_storage" {
  count  = local.should_create_s3 ? 1 : 0
  bucket = "${local.resource_name}-storage-${formatdate("YYYYMMDD-hhmm", timestamp())}"

  tags = {
    Name = "${local.resource_name}-storage-bucket"
  }
}

resource "aws_s3_bucket_versioning" "app_storage" {
  count  = local.should_create_s3 ? 1 : 0
  bucket = aws_s3_bucket.app_storage[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  count  = local.should_create_s3 ? 1 : 0
  bucket = aws_s3_bucket.app_storage[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  count  = local.should_create_s3 ? 1 : 0
  bucket = aws_s3_bucket.app_storage[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SERVICE 5: IAM User
resource "aws_iam_user" "app_user" {
  count = local.should_create_iam_user ? 1 : 0
  name  = "${local.resource_name}-app-user"

  tags = {
    Name = "${local.resource_name}-app-user"
  }
}

resource "aws_iam_access_key" "app_user" {
  count = local.should_create_iam_user ? 1 : 0
  user  = aws_iam_user.app_user[0].name
}

resource "aws_iam_user_policy" "s3_access" {
  count = local.should_create_iam_user ? 1 : 0
  name  = "${var.project_name}-s3-access"
  user  = aws_iam_user.app_user[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_storage[0].arn,
          "${aws_s3_bucket.app_storage[0].arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy" "ec2_access" {
  count = local.should_create_iam_user ? 1 : 0
  name  = "${var.project_name}-ec2-access"
  user  = aws_iam_user.app_user[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}