#!/bin/bash
set -e
exec > >(tee /var/log/setup.log)
exec 2>&1

echo "======================================"
echo "Starting EC2 Setup"
echo "======================================"

# Update system
yum update -y
yum install -y git curl wget java-17-amazon-corretto-headless

# Install Docker
amazon-linux-extras install -y docker
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user
echo "✅ Docker installed"

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo "✅ Docker Compose installed"

# Install Jenkins with correct repo and GPG key
tee /etc/yum.repos.d/jenkins.repo > /dev/null << 'JENKINS_EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
JENKINS_EOF

rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y fontconfig java-17-amazon-corretto-headless
yum install -y jenkins

systemctl enable jenkins
systemctl start jenkins
sleep 15
echo "✅ Jenkins installed and started"

# Clone Docker Services Repository
mkdir -p /opt/docker-services
cd /opt/docker-services
git clone https://github.com/ItsAnurag27/5-service-jenkins-pipeline.git . || echo "⚠️ Git clone warning"
echo "✅ Repository cloned"

echo "======================================"
echo "✅ SETUP COMPLETE!"
echo "======================================"
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo "Jenkins: Running at http://localhost:8080"
echo "Repository: /opt/docker-services"
echo "======================================"
