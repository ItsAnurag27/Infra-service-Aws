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
    }
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Get Available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# SERVICE 1: VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
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
    
    # Update system packages
    yum update -y
    yum install -y java-17-amazon-corretto-headless git curl wget
    
    # Add Jenkins repository
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    
    # Install Jenkins
    yum install -y jenkins
    
    # Enable and start Jenkins service
    systemctl enable jenkins
    systemctl start jenkins
    
    # Wait for Jenkins to be ready
    sleep 30
    
    # Get Jenkins initial admin password
    JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "")
    
    # Create Jenkins configuration to skip wizard
    mkdir -p /var/lib/jenkins
    
    # Set up Jenkins to skip setup wizard
    cat > /var/lib/jenkins/jenkins.install.UpgradeWizard.state <<'JENKINS_CONFIG'
    2.414
    JENKINS_CONFIG
    
    # Create initial Jenkins user (admin:admin)
    cat > /var/lib/jenkins/users/admin/config.xml <<'JENKINS_USER'
    <?xml version='1.1' encoding='UTF-8'?>
    <hudson.model.User>
      <id>admin</id>
      <fullName>Administrator</fullName>
      <properties>
        <hudson.security.HudsonPrivateSecurityRealm_-Details>
          <passwordHash>#jbcrypt:$2a$10$yYjSW8kVZXSGOQaX4bxPxuREH7ZfvFDMcIwE.kfh0GBHfXiJBcuBe</passwordHash>
        </hudson.security.HudsonPrivateSecurityRealm_-Details>
        <jenkins.security.ApiTokenProperty>
          <tokenStore>
            <map class="hudson.util.CopyOnWriteMap$Hash"/>
          </tokenStore>
        </jenkins.security.ApiTokenProperty>
      </properties>
    </hudson.model.User>
    JENKINS_USER
    
    # Set proper permissions
    chown -R jenkins:jenkins /var/lib/jenkins
    chmod -R 755 /var/lib/jenkins
    
    # Restart Jenkins to apply configuration
    systemctl restart jenkins
    
    # Wait for Jenkins to fully start
    sleep 30
    
    # Install Jenkins CLI and manage plugins
    JENKINS_URL="http://localhost:8080"
    
    # Function to wait for Jenkins to be ready
    wait_for_jenkins() {
      for i in {1..60}; do
        if curl -s "$JENKINS_URL/cli/" > /dev/null 2>&1; then
          return 0
        fi
        sleep 2
      done
      return 1
    }
    
    # Wait for Jenkins to be ready
    wait_for_jenkins
    
    # Download Jenkins CLI
    curl -o /tmp/jenkins-cli.jar "$JENKINS_URL/jnlpJars/jenkins-cli.jar"
    
    # Install essential plugins using Jenkins CLI
    java -jar /tmp/jenkins-cli.jar -s "$JENKINS_URL" -auth admin:admin install-plugin \
      pipeline-model-definition \
      pipeline-stage-view \
      git \
      github \
      docker-plugin \
      docker-pipeline \
      ws-cleanup \
      credentials \
      ssh-agent \
      sonar \
      -restart
    
    # Wait for plugins to install
    sleep 20
    
    # Restart Jenkins
    systemctl restart jenkins
    
    # Wait for Jenkins to be fully ready
    sleep 30
    
    # Create GitHub credentials in Jenkins
    GITHUB_TOKEN="${var.github_token}"
    GITHUB_USER="${var.github_username}"
    
    if [ ! -z "$GITHUB_TOKEN" ] && [ ! -z "$GITHUB_USER" ]; then
      # Create GitHub credentials XML
      cat > /tmp/create_credentials.groovy <<'GITHUB_CREDS'
def store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def domain = com.cloudbees.plugins.credentials.domains.Domain.global()

def cred = new org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  "github-token",
  "GitHub Token",
  SecretBytes.fromString("GITHUB_TOKEN_PLACEHOLDER")
)

store.addCredentials(domain, cred)
Jenkins.instance.save()

// Also create GitHub credentials with username
def githubCred = new com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL,
  "github-credentials",
  "GitHub Credentials",
  "GITHUB_USER_PLACEHOLDER",
  "GITHUB_TOKEN_PLACEHOLDER"
)

store.addCredentials(domain, githubCred)
Jenkins.instance.save()

println "GitHub credentials created successfully"
GITHUB_CREDS

      # Replace placeholders with actual values
      sed -i "s|GITHUB_TOKEN_PLACEHOLDER|$GITHUB_TOKEN|g" /tmp/create_credentials.groovy
      sed -i "s|GITHUB_USER_PLACEHOLDER|$GITHUB_USER|g" /tmp/create_credentials.groovy

      # Create a script to run Groovy in Jenkins
      java -jar /tmp/jenkins-cli.jar -s "http://localhost:8080" -auth admin:admin groovy = < /tmp/create_credentials.groovy || true
    fi
    
    # Generate SSH key pair for Jenkins to EC2 deployment (jenkins-key)
    echo "Generating SSH key pair for Jenkins pipeline..."
    mkdir -p /var/lib/jenkins/.ssh
    
    # Generate RSA key pair
    ssh-keygen -t rsa -b 4096 -f /var/lib/jenkins/.ssh/jenkins-key -N "" -C "jenkins@15-services"
    
    # Get the public key
    JENKINS_PUB_KEY=$(cat /var/lib/jenkins/.ssh/jenkins-key.pub)
    
    # Add public key to authorized_keys for ec2-user
    mkdir -p /home/ec2-user/.ssh
    echo "$JENKINS_PUB_KEY" >> /home/ec2-user/.ssh/authorized_keys
    chmod 600 /home/ec2-user/.ssh/authorized_keys
    chmod 700 /home/ec2-user/.ssh
    
    # Set proper permissions for Jenkins SSH key
    chmod 600 /var/lib/jenkins/.ssh/jenkins-key
    chmod 644 /var/lib/jenkins/.ssh/jenkins-key.pub
    chown -R jenkins:jenkins /var/lib/jenkins/.ssh
    
    # Create SSH credentials in Jenkins using Groovy
    cat > /tmp/create_ssh_credentials.groovy <<'SSH_CREDS'
def store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def domain = com.cloudbees.plugins.credentials.domains.Domain.global()

// Read the private key
def keyFile = new File("/var/lib/jenkins/.ssh/jenkins-key")
def privateKey = keyFile.text

// Create SSH key credential
def sshCred = new com.cloudbees.jenkins.plugins.kubernetes.credentials.OpenShiftBearerTokenCredentialImpl(
  CredentialsScope.GLOBAL,
  "jenkins-key",
  "Jenkins SSH Key for EC2",
  SecretBytes.fromString(privateKey)
)

// Use BasicSSHUserPrivateKey instead
def sshKey = new hudson.util.Secret(privateKey)
def keySource = new com.cloudbees.jenkins.plugins.kubernetes.credentials.impl.BasicSSHUserPrivateKey(
  CredentialsScope.GLOBAL,
  "jenkins-key",
  "ec2-user",
  new com.cloudbees.jenkins.plugins.kubernetes.credentials.impl.BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(sshKey),
  "",
  "Jenkins SSH Key for EC2"
)

store.addCredentials(domain, keySource)
Jenkins.instance.save()

println "SSH credentials created successfully"
SSH_CREDS

    # Run the Groovy script to create SSH credentials
    java -jar /tmp/jenkins-cli.jar -s "http://localhost:8080" -auth admin:admin groovy = < /tmp/create_ssh_credentials.groovy || true
    
    # Wait for credentials to be created
    sleep 5
    
    # Restart Jenkins to ensure credentials are loaded
    systemctl restart jenkins
    sleep 20
    
    # Allow HTTP traffic on port 8080
    cat > /etc/yum.repos.d/amazon-linux-extras.repo <<'FIREWALL'
    [amazon-linux-extras]
    name=Amazon Linux Extras
    baseurl=https://cdn.amazonlinux.com/data/extras/repo/2/x86_64/latest/
    enabled=1
    gpgcheck=1
    gpgkey=https://amazon-linux-ami.s3.amazonaws.com/RPM-GPG-KEY-amazon-linux-extras
    FIREWALL
    
    echo "Jenkins installation and setup completed!"
    echo "Jenkins URL: $JENKINS_URL"
    echo "Username: admin"
    echo "Password: admin"
  EOF
  )

  tags = {
    Name = "15-services-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Associate Elastic IP with first EC2 instance
resource "aws_eip_association" "app" {
  count         = var.ec2_instance_count > 0 ? 1 : 0
  instance_id   = aws_instance.app[0].id
  allocation_id = var.elastic_ip_allocation_id
}

# SERVICE 4: S3 Bucket for Storage
resource "aws_s3_bucket" "app_storage" {
  bucket = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-storage-bucket"
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
  name = "${var.project_name}-app-user"

  tags = {
    Name = "${var.project_name}-app-user"
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