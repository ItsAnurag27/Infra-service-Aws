#!/bin/bash
# Jenkins installation and diagnostic script

echo "=========================================="
echo "Jenkins Troubleshooting Script"
echo "=========================================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use: sudo)"
   exit 1
fi

echo ""
echo "📋 Step 1: Checking Java Installation..."
if command -v java &> /dev/null; then
    echo "✅ Java is installed:"
    java -version
else
    echo "❌ Java NOT found. Installing..."
    yum install -y java-17-amazon-corretto-headless
    java -version
fi

echo ""
echo "📋 Step 2: Checking Jenkins Repository..."
if [ -f /etc/yum.repos.d/jenkins.repo ]; then
    echo "✅ Jenkins repo file exists"
    cat /etc/yum.repos.d/jenkins.repo
else
    echo "❌ Jenkins repo file missing. Adding..."
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
fi

echo ""
echo "📋 Step 3: Installing Jenkins Package..."
yum install -y jenkins

echo ""
echo "📋 Step 4: Starting Jenkins Service..."
systemctl enable jenkins
systemctl start jenkins
systemctl status jenkins

echo ""
echo "📋 Step 5: Checking Jenkins Service..."
sleep 5
if systemctl is-active --quiet jenkins; then
    echo "✅ Jenkins is running"
    echo ""
    echo "📋 Step 6: Waiting for Jenkins web interface (max 60 seconds)..."
    for i in {1..60}; do
        if curl -s http://localhost:8080 >/dev/null 2>&1; then
            echo "✅ Jenkins web interface is accessible at http://localhost:8080"
            break
        fi
        echo "⏳ Attempt $i/60..."
        sleep 2
    done
else
    echo "❌ Jenkins is NOT running"
    echo "Last 50 lines of Jenkins log:"
    journalctl -u jenkins -n 50
fi

echo ""
echo "✅ Jenkins installation complete!"
echo "Access Jenkins at: http://localhost:8080"
echo ""
echo "To get the initial admin password, run:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
