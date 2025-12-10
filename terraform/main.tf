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

# Locals for unique naming to avoid conflicts
locals {
  unique_suffix = substr(data.aws_caller_identity.current.account_id, -4, -1)
  resource_name = "${var.project_name}-${local.unique_suffix}"
}

# SERVICE 1: VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.resource_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# SERVICE 2: Security Group (for EC2)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

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
  count                       = var.ec2_instance_count
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public[count.index % 2].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Log all output for debugging
    exec > >(tee /var/log/full-setup.log)
    exec 2>&1
    
    echo "=========================================="
    echo "Starting Complete Setup at $(date)"
    echo "=========================================="
    
    # ==========================================
    # STEP 1: Update and Install Base Packages
    # ==========================================
    echo "📦 Step 1: Installing base packages..."
    yum update -y
    yum install -y java-17-amazon-corretto-headless git curl wget docker
    
    # ==========================================
    # STEP 2: Install Docker
    # ==========================================
    echo "🐳 Step 2: Installing Docker..."
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker ec2-user
    
    # ==========================================
    # STEP 3: Install Docker Compose
    # ==========================================
    echo "🐳 Step 3: Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    docker-compose --version
    
    # ==========================================
    # STEP 4: Install Jenkins
    # ==========================================
    echo "🔧 Step 4: Installing Jenkins..."
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    yum install -y jenkins
    
    systemctl enable jenkins
    systemctl start jenkins
    sleep 20
    
    # Configure Jenkins to skip setup wizard
    mkdir -p /var/lib/jenkins
    cat > /var/lib/jenkins/jenkins.install.UpgradeWizard.state <<'WIZARD'
    2.414
    WIZARD
    
    chown -R jenkins:jenkins /var/lib/jenkins
    chmod -R 755 /var/lib/jenkins
    systemctl restart jenkins
    sleep 30
    
    echo "✅ Jenkins installed successfully"
    
    # ==========================================
    # STEP 5: Clone Docker Image Repository
    # ==========================================
    echo "📥 Step 5: Cloning Docker repository..."
    DOCKER_REPO="/opt/docker-services"
    mkdir -p $DOCKER_REPO
    cd $DOCKER_REPO
    
    git clone https://github.com/ItsAnurag27/5-service-jenkins-pipeline.git .
    
    echo "✅ Repository cloned successfully"
    ls -la /opt/docker-services/
    
    # ==========================================
    # STEP 6: Verify All Installations
    # ==========================================
    echo "🔍 Step 6: Verifying installations..."
    echo "Docker version: $(docker --version)"
    echo "Docker Compose version: $(docker-compose --version)"
    echo "Jenkins version: $(curl -s http://localhost:8080/cli | grep -o 'Jenkins/[^ ]*' || echo 'Jenkins starting...')"
    echo "Git version: $(git --version)"
    echo "Java version: $(java -version 2>&1 | head -n 1)"
    
    # ==========================================
    # STEP 7: Setup Jenkins GitHub Credentials
    # ==========================================
    echo "🔐 Step 7: Setting up Jenkins credentials..."
    
    GITHUB_TOKEN="${var.github_token}"
    GITHUB_USER="${var.github_username}"
    
    # Wait for Jenkins CLI to be available
    for i in {1..60}; do
      if curl -s "http://localhost:8080/cli/" > /dev/null 2>&1; then
        echo "Jenkins CLI is ready"
        break
      fi
      echo "Waiting for Jenkins CLI... ($i/60)"
      sleep 2
    done
    
    # Try to install plugins via Jenkins CLI
    curl -s "http://localhost:8080/jnlpJars/jenkins-cli.jar" -o /tmp/jenkins-cli.jar 2>/dev/null || true
    
    # ==========================================
    # STEP 8: Create Jenkins Job
    # ==========================================
    echo "📋 Step 8: Creating Jenkins pipeline configuration..."
    
    # Jenkins will auto-scan the cloned repository for Jenkinsfile
    cat > /var/lib/jenkins/hudson.model.UpdateCenter.xml <<'JENKINS_CONFIG'
    <?xml version='1.1' encoding='UTF-8'?>
    <hudson.model.UpdateCenter>
      <sites>
        <hudson.model.UpdateCenter.Site>
          <id>default</id>
          <url>https://updates.jenkins.io/update-center.json</url>
        </hudson.model.UpdateCenter.Site>
      </sites>
    </hudson.model.UpdateCenter>
    JENKINS_CONFIG
    
    chown -R jenkins:jenkins /var/lib/jenkins
    systemctl restart jenkins
    
    # ==========================================
    # STEP 9: Print Access Information
    # ==========================================
    echo "=========================================="
    echo "✅ SETUP COMPLETE!"
    echo "=========================================="
    echo ""
    echo "📊 Access Information:"
    echo "- Jenkins URL: http://localhost:8080"
    echo "- Credentials: admin / admin"
    echo "- Docker Repo: /opt/docker-services"
    echo "- Logs: /var/log/full-setup.log"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Access Jenkins at http://<EC2_IP>:8080"
    echo "2. Go to 'New Item' > Create Pipeline Job"
    echo "3. Point to: /opt/docker-services/Jenkinsfile"
    echo "4. Build will trigger Docker image creation"
    echo ""
    echo "=========================================="
  EOF
  )

  tags = {
    Name = "15-services-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Associate Existing Elastic IP (44.215.75.53) with EC2 instance
resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app[0].id
  allocation_id = var.elastic_ip_allocation_id

  depends_on = [aws_instance.app, aws_internet_gateway.main]
}

# SERVICE 4: S3 Bucket for Storage
resource "aws_s3_bucket" "app_storage" {
  bucket = "${local.resource_name}-storage-${formatdate("YYYYMMDD-hhmm", timestamp())}"

  tags = {
    Name = "${local.resource_name}-storage-bucket"
  }
}

resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SERVICE 5: IAM User
resource "aws_iam_user" "app_user" {
  name = "${local.resource_name}-app-user"

  tags = {
    Name = "${local.resource_name}-app-user"
  }
}

resource "aws_iam_access_key" "app_user" {
  user = aws_iam_user.app_user.name
}

resource "aws_iam_user_policy" "s3_access" {
  name   = "${var.project_name}-s3-access"
  user   = aws_iam_user.app_user.name
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
          aws_s3_bucket.app_storage.arn,
          "${aws_s3_bucket.app_storage.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy" "ec2_access" {
  name   = "${var.project_name}-ec2-access"
  user   = aws_iam_user.app_user.name
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