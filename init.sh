#!/bin/bash
set -e

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║       Gully-1 (DGX Spark) - Global Server Initialization         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Install K3s if not present
if ! command -v k3s &> /dev/null; then
    log_info "Installing K3s (Local Kubernetes)..."
    curl -sfL https://get.k3s.io | sh -
    echo "Waiting for K3s to start..."
    sleep 30
    sudo k3s kubectl get nodes
    log_success "K3s installed"
else
    log_info "K3s already installed, skipping"
fi

# Configure kubectl for non-root usage
if [ ! -f ~/.kube/config ]; then
    log_info "Configuring kubectl..."
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    log_success "kubectl configured"
else
    log_info "kubectl already configured, skipping"
fi

# Install envsubst if not present
if ! command -v envsubst &> /dev/null; then
    log_info "Installing gettext (for envsubst)..."
    sudo apt-get update && sudo apt-get install -y gettext
    log_success "gettext installed"
else
    log_info "envsubst already available, skipping"
fi

# Install tmux if not present
if ! command -v tmux &> /dev/null; then
    log_info "Installing tmux..."
    sudo apt-get update && sudo apt-get install -y tmux
else
    log_info "tmux already installed, skipping"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                 Server Setup Complete!                           ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                  ║"
echo "║  Next steps: Initialize each environment separately.             ║"
echo "║                                                                  ║"
echo "║  1. Go to an environment folder:                                 ║"
echo "║     cd gully-prod (or gully-dev, gully-demo)                     ║"
echo "║                                                                  ║"
echo "║  2. Create and edit .env:                                        ║"
echo "║     cp .env.example .env && nano .env                            ║"
echo "║                                                                  ║"
echo "║  3. Create Docker Hub secret for that namespace:                 ║"
echo "║     kubectl create secret docker-registry dockerhub ...          ║"
echo "║                                                                  ║"
echo "║  4. Deploy the environment:                                      ║"
echo "║     ./deploy.sh                                                  ║"
echo "║                                                                  ║"
echo "║  Multiple environments can run simultaneously on this server.    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
