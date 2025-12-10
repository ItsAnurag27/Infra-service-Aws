#!/bin/bash
set -e

# Logging setup
LOG_FILE="/var/log/jenkins-install.log"
exec > >(tee "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "JENKINS INSTALLATION STAGE"
echo "======================================"
echo "Start Time: $(date)"
echo ""

# Stage 1: Create Jenkins repo config
echo "📦 [STAGE 1] Creating Jenkins repository configuration..."
try_count=0
max_tries=3

while [ $try_count -lt $max_tries ]; do
  if tee /etc/yum.repos.d/jenkins.repo > /dev/null << 'JENKINS_EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
JENKINS_EOF
  then
    echo "✅ [STAGE 1] Repository config created successfully"
    break
  else
    try_count=$((try_count + 1))
    echo "⚠️  [STAGE 1] Attempt $try_count failed, retrying..."
    sleep 5
  fi
done

if [ $try_count -eq $max_tries ]; then
  echo "❌ [STAGE 1] FAILED to create repository config after $max_tries attempts"
  exit 1
fi

# Stage 2: Import GPG key
echo ""
echo "🔑 [STAGE 2] Importing Jenkins GPG key..."
if rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key 2>&1; then
  echo "✅ [STAGE 2] GPG key imported successfully"
else
  echo "⚠️  [STAGE 2] GPG key import had issues, continuing anyway..."
fi

# Stage 3: Install fontconfig and Java
echo ""
echo "☕ [STAGE 3] Installing fontconfig and Java 17..."
if yum install -y fontconfig java-17-amazon-corretto-headless; then
  echo "✅ [STAGE 3] fontconfig and Java installed successfully"
else
  echo "❌ [STAGE 3] FAILED to install fontconfig/Java"
  exit 1
fi

# Stage 4: Verify Java installation
echo ""
echo "🔍 [STAGE 4] Verifying Java installation..."
JAVA_VERSION=$(java -version 2>&1)
echo "Java version: $JAVA_VERSION"
echo "✅ [STAGE 4] Java verification complete"

# Stage 5: Install Jenkins
echo ""
echo "📥 [STAGE 5] Installing Jenkins package..."
if yum install -y jenkins; then
  echo "✅ [STAGE 5] Jenkins package installed successfully"
else
  echo "❌ [STAGE 5] FAILED to install Jenkins package"
  exit 1
fi

# Stage 6: Verify Jenkins installation
echo ""
echo "🔍 [STAGE 6] Verifying Jenkins installation..."
if rpm -qa | grep -q jenkins; then
  JENKINS_VERSION=$(rpm -qa | grep jenkins)
  echo "✅ [STAGE 6] Jenkins installed: $JENKINS_VERSION"
else
  echo "❌ [STAGE 6] FAILED: Jenkins package not found after installation"
  exit 1
fi

# Stage 7: Enable Jenkins service
echo ""
echo "🚀 [STAGE 7] Enabling Jenkins service..."
if systemctl enable jenkins; then
  echo "✅ [STAGE 7] Jenkins service enabled"
else
  echo "❌ [STAGE 7] FAILED to enable Jenkins service"
  exit 1
fi

# Stage 8: Start Jenkins service
echo ""
echo "▶️  [STAGE 8] Starting Jenkins service..."
if systemctl start jenkins; then
  echo "✅ [STAGE 8] Jenkins service started"
else
  echo "❌ [STAGE 8] FAILED to start Jenkins service"
  systemctl status jenkins || true
  exit 1
fi

# Stage 9: Wait for Jenkins to be ready
echo ""
echo "⏳ [STAGE 9] Waiting for Jenkins to be fully ready..."
sleep 15

# Stage 10: Verify Jenkins is running
echo ""
echo "🔍 [STAGE 10] Verifying Jenkins is running..."
if systemctl is-active --quiet jenkins; then
  echo "✅ [STAGE 10] Jenkins service is active and running"
else
  echo "❌ [STAGE 10] FAILED: Jenkins service is not running"
  systemctl status jenkins || true
  exit 1
fi

# Stage 11: Check Jenkins web interface
echo ""
echo "🌐 [STAGE 11] Checking Jenkins web interface on port 8080..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|403"; then
  echo "✅ [STAGE 11] Jenkins web interface is responding"
else
  echo "⚠️  [STAGE 11] Jenkins web interface not responding yet (this is normal during startup)"
fi

# Final summary
echo ""
echo "======================================"
echo "✅ JENKINS INSTALLATION COMPLETE!"
echo "======================================"
echo "Jenkins Status: $(systemctl is-active jenkins)"
echo "Jenkins Version: $(rpm -qa | grep jenkins)"
echo "Jenkins URL: http://localhost:8080"
echo "Log file: $LOG_FILE"
echo "End Time: $(date)"
echo "======================================"
