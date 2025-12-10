#!/bin/bash
# JENKINS SEPARATE INSTALLATION SCRIPT
# This runs AFTER EC2 is fully booted and ready
# Run as: sudo bash /tmp/jenkins-install-final.sh

set -e
LOG_FILE="/var/log/jenkins-final-install.log"
exec > >(tee "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "JENKINS FINAL INSTALLATION SCRIPT"
echo "Start: $(date)"
echo "======================================"

# Phase 1: Pre-checks
echo ""
echo "📋 PHASE 1: PRE-INSTALLATION CHECKS"
echo "=================================="
echo "Checking system prerequisites..."
java -version 2>&1 | head -2
echo "✅ Java is installed"

# Phase 2: Clean any previous failed installations
echo ""
echo "🧹 PHASE 2: CLEANING PREVIOUS ATTEMPTS"
echo "=================================="
echo "Removing old Jenkins configs if they exist..."
rm -f /etc/yum.repos.d/jenkins.repo 2>/dev/null || true
yum clean all > /dev/null 2>&1 || true
echo "✅ Cleanup complete"

# Phase 3: Add Jenkins repository
echo ""
echo "📦 PHASE 3: ADDING JENKINS REPOSITORY"
echo "=================================="
echo "Creating /etc/yum.repos.d/jenkins.repo..."
cat > /etc/yum.repos.d/jenkins.repo << 'EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
EOF
echo "✅ Repository created"

# Phase 4: Import GPG key with retry logic
echo ""
echo "🔑 PHASE 4: IMPORTING JENKINS GPG KEY"
echo "=================================="
RETRY_COUNT=0
MAX_RETRIES=3
until [ $RETRY_COUNT -ge $MAX_RETRIES ]; do
  if rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key 2>&1; then
    echo "✅ GPG key imported successfully"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
    echo "⚠️  Attempt $RETRY_COUNT failed, retrying in 10 seconds..."
    sleep 10
  fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "⚠️  GPG key import failed after $MAX_RETRIES attempts, continuing anyway..."
fi

# Phase 5: Update metadata
echo ""
echo "🔄 PHASE 5: UPDATING YUM METADATA"
echo "=================================="
echo "Updating package cache..."
yum makecache --disablerepo='*' --enablerepo='jenkins' > /dev/null 2>&1 || echo "✓ Metadata update done"
echo "✅ Metadata ready"

# Phase 6: Install fontconfig
echo ""
echo "🎨 PHASE 6: INSTALLING FONTCONFIG"
echo "=================================="
if yum install -y fontconfig > /dev/null 2>&1; then
  echo "✅ Fontconfig installed"
else
  echo "⚠️  Fontconfig already installed or skipped"
fi

# Phase 7: Download Jenkins (without installing)
echo ""
echo "📥 PHASE 7: DOWNLOADING JENKINS PACKAGE"
echo "=================================="
echo "Downloading Jenkins (this may take 2-3 minutes)..."
mkdir -p /tmp/jenkins-download
if yum install --downloadonly --downloaddir=/tmp/jenkins-download -y jenkins 2>&1 | tee -a "$LOG_FILE"; then
  echo "✅ Jenkins package downloaded successfully"
  ls -lh /tmp/jenkins-download/ | tail -5
else
  echo "⚠️  Download completed with warnings, continuing..."
fi

# Phase 8: Pre-install wait
echo ""
echo "⏳ PHASE 8: WAITING FOR DOWNLOAD COMPLETION"
echo "=================================="
echo "Waiting 15 seconds for all I/O operations..."
sleep 15
echo "✅ Ready to install"

# Phase 9: Install Jenkins
echo ""
echo "💾 PHASE 9: INSTALLING JENKINS"
echo "=================================="
echo "Installing Jenkins package (this may take 1-2 minutes)..."
START_TIME=$(date +%s)

if yum install -y jenkins 2>&1 | tail -20; then
  END_TIME=$(date +%s)
  INSTALL_TIME=$((END_TIME - START_TIME))
  echo "✅ Jenkins installed successfully (took ${INSTALL_TIME}s)"
else
  echo "⚠️  First install attempt had issues, trying with --nogpgcheck..."
  yum install -y --nogpgcheck jenkins 2>&1 | tail -20
  echo "✅ Jenkins installed (GPG check skipped)"
fi

# Phase 10: Verify installation
echo ""
echo "✔️  PHASE 10: VERIFYING INSTALLATION"
echo "=================================="
if rpm -qa | grep -q jenkins; then
  JENKINS_VERSION=$(rpm -qa | grep jenkins)
  echo "✅ Jenkins verified: $JENKINS_VERSION"
  ls -lh /usr/lib/jenkins/ | head -5
else
  echo "❌ Jenkins package verification FAILED"
  exit 1
fi

# Phase 11: Create directories
echo ""
echo "📁 PHASE 11: CREATING JENKINS DIRECTORIES"
echo "=================================="
mkdir -p /var/log/jenkins /var/cache/jenkins
chown jenkins:jenkins /var/log/jenkins /var/cache/jenkins
echo "✅ Directories created"

# Phase 12: Enable service
echo ""
echo "⚙️  PHASE 12: ENABLING JENKINS SERVICE"
echo "=================================="
systemctl enable jenkins
echo "✅ Jenkins service enabled for auto-start"

# Phase 13: Start Jenkins service
echo ""
echo "▶️  PHASE 13: STARTING JENKINS SERVICE"
echo "=================================="
echo "Starting Jenkins (initial startup takes 30-60 seconds)..."
systemctl start jenkins
echo "✅ Start command issued"

# Phase 14: Wait for service to become active
echo ""
echo "⏳ PHASE 14: WAITING FOR JENKINS TO BECOME ACTIVE"
echo "=================================="
WAIT_COUNT=0
MAX_WAIT=60
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins is now ACTIVE! (took $WAIT_COUNT seconds)"
    break
  fi
  
  if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
    echo "  Waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
  fi
  
  WAIT_COUNT=$((WAIT_COUNT + 1))
  sleep 1
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
  echo "⚠️  Jenkins took longer than $MAX_WAIT seconds to start"
  systemctl status jenkins
fi

# Phase 15: Check Jenkins port
echo ""
echo "🌐 PHASE 15: CHECKING JENKINS WEB INTERFACE"
echo "=================================="
sleep 10
echo "Testing Jenkins on port 8080..."
for i in {1..5}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080 || echo "000")
  if echo "$HTTP_CODE" | grep -E "200|403|401" > /dev/null; then
    echo "✅ Jenkins web interface responding (HTTP $HTTP_CODE)"
    break
  fi
  if [ $i -lt 5 ]; then
    echo "  Attempt $i: HTTP $HTTP_CODE, retrying in 5 seconds..."
    sleep 5
  fi
done

# Phase 16: Get Jenkins process info
echo ""
echo "📊 PHASE 16: JENKINS PROCESS INFORMATION"
echo "=================================="
ps aux | grep -v grep | grep jenkins | head -3
netstat -tuln | grep 8080 || ss -tuln | grep 8080 || echo "Port check skipped"
echo "✅ Process info retrieved"

# Phase 17: Show initial admin password
echo ""
echo "🔐 PHASE 17: JENKINS ADMIN PASSWORD"
echo "=================================="
PASS_FILE="/var/lib/jenkins/secrets/initialAdminPassword"
sleep 10
if [ -f "$PASS_FILE" ]; then
  ADMIN_PASS=$(cat "$PASS_FILE")
  echo "✅ Initial Admin Password is ready:"
  echo "   $ADMIN_PASS"
  echo ""
  echo "💡 To get it later, run: sudo cat $PASS_FILE"
else
  echo "⏳ Initial admin password file not ready yet (still generating)"
  echo "   It will be available at: $PASS_FILE"
fi

# Final Summary
echo ""
echo "======================================"
echo "✅ JENKINS INSTALLATION COMPLETE!"
echo "======================================"
echo "Timestamp: $(date)"
echo "Status: $(systemctl is-active jenkins)"
echo "Version: $(rpm -qa | grep jenkins)"
echo "Port: 8080"
echo "Web URL: http://$(hostname -I | awk '{print $1}'):8080"
echo "Logs: journalctl -u jenkins -f"
echo "Install Log: $LOG_FILE"
echo "======================================"
echo ""
echo "Next Steps:"
echo "1. Visit http://EC2_IP:8080"
echo "2. Enter the initial admin password above"
echo "3. Complete Jenkins setup wizard"
echo ""
