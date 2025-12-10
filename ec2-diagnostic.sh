#!/bin/bash
# Diagnostic script to check what happened during setup

echo "=========================================="
echo "EC2 Setup Diagnostic Report"
echo "=========================================="
echo ""

echo "📋 STEP 1: Check Docker Installation"
echo "---"
if command -v docker &> /dev/null; then
    echo "✅ Docker found at: $(which docker)"
    docker --version
else
    echo "❌ Docker NOT installed"
fi

echo ""
echo "📋 STEP 2: Check Docker Compose Installation"
echo "---"
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose found at: $(which docker-compose)"
    docker-compose --version
else
    echo "❌ Docker Compose NOT installed"
fi

echo ""
echo "📋 STEP 3: Check Jenkins Installation"
echo "---"
if systemctl list-unit-files jenkins.service 2>/dev/null | grep -q jenkins; then
    echo "✅ Jenkins service file exists"
    systemctl status jenkins
else
    echo "❌ Jenkins service NOT found"
fi

echo ""
echo "📋 STEP 4: Check Java Installation"
echo "---"
if command -v java &> /dev/null; then
    echo "✅ Java installed:"
    java -version
else
    echo "❌ Java NOT installed"
fi

echo ""
echo "📋 STEP 5: Review Setup Logs"
echo "---"
if [ -f /var/log/full-setup.log ]; then
    echo "Setup log found. Last 100 lines:"
    echo ""
    tail -100 /var/log/full-setup.log
else
    echo "❌ Setup log not found at /var/log/full-setup.log"
fi

echo ""
echo "📋 STEP 6: Check Git Clone Log"
echo "---"
if [ -f /var/log/git-clone.log ]; then
    echo "Git clone log found:"
    echo ""
    cat /var/log/git-clone.log
else
    echo "ℹ️  Git clone log not found (may not have run)"
fi

echo ""
echo "=========================================="
echo "End of Diagnostic Report"
echo "=========================================="
