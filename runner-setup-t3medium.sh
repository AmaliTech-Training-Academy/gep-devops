#!/bin/bash
set -e

echo "🚀 Setting up unified runner on t3.medium for backend + frontend + Go"

# Update system
sudo apt update && sudo apt upgrade -y

# 1. Java 21 (Backend - Maven builds)
echo "📦 Installing Java 21..."
sudo apt install -y openjdk-21-jdk
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> ~/.bashrc

# 2. Maven (Backend builds)
echo "📦 Installing Maven..."
sudo apt install -y maven

# 3. Node.js 18+ (Frontend builds)
echo "📦 Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 4. Docker (Container builds)
echo "📦 Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 5. AWS CLI v2 (Deployments)
echo "📦 Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# 6. Go (Your requirement)
echo "📦 Installing Go..."
GO_VERSION="1.21.5"
wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc

# 7. Essential tools
echo "📦 Installing essential tools..."
sudo apt install -y jq git curl wget unzip

# 8. GitHub Actions Runner
echo "📦 Installing GitHub Actions Runner..."
mkdir -p ~/actions-runner && cd ~/actions-runner
RUNNER_VERSION="2.311.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

echo ""
echo "✅ Installation complete!"
echo ""
echo "📋 Installed versions:"
java -version
mvn -version
node -v
npm -v
docker --version
aws --version
go version
# echo ""
# echo "⚠️  IMPORTANT: Logout and login again for Docker group to take effect"
# echo ""
# echo "🔧 Next steps:"
# echo "1. Logout and login: exit"
# echo "2. Configure runner:"
# echo "   cd ~/actions-runner"
# echo "   ./config.sh --url https://github.com/YOUR_ORG/gep_devops \\"
# echo "     --token YOUR_TOKEN \\"
# echo "     --name unified-runner \\"
# echo "     --labels self-hosted,backend,frontend,linux"
# echo "3. Install as service:"
# echo "   sudo ./svc.sh install"
# echo "   sudo ./svc.sh start"
