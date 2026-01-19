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

# Detect environment from folder name
ENV_DIR=$(basename "$(pwd)")
ENV_NAME=${ENV_DIR#gully-}

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║       Gully-1 - Environment Setup: $ENV_DIR                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if global init has been run
if ! command -v k3s &> /dev/null; then
    log_warn "K3s not found. Did you run the root init.sh first?"
    echo "Please run: cd .. && ./init.sh"
    exit 1
fi

# Create .env from template
if [ ! -f .env ]; then
    log_info "Creating .env for $ENV_DIR..."
    cp .env.example .env
    # Pre-populate some values based on environment
    # Use portable sed syntax (works on both macOS and Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS/BSD sed requires empty string after -i
        sed -i '' "s/ENVIRONMENT_NAME=my-environment/ENVIRONMENT_NAME=$ENV_DIR/" .env
        sed -i '' "s/NAMESPACE=digital-tvilling-\${ENVIRONMENT_NAME}/NAMESPACE=$ENV_DIR/" .env
        sed -i '' "s/DOMAIN=\${NAMESPACE}/DOMAIN=$ENV_DIR/" .env
    else
        # Linux sed doesn't require empty string
        sed -i "s/ENVIRONMENT_NAME=my-environment/ENVIRONMENT_NAME=$ENV_DIR/" .env
        sed -i "s/NAMESPACE=digital-tvilling-\${ENVIRONMENT_NAME}/NAMESPACE=$ENV_DIR/" .env
        sed -i "s/DOMAIN=\${NAMESPACE}/DOMAIN=$ENV_DIR/" .env
    fi
    log_success "Created .env with environment defaults"
else
    log_info ".env already exists, skipping"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                 Environment Setup Complete!                      ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                  ║"
echo "║  1. Edit .env with your secrets and Tailscale IP:                ║"
echo "║     nano .env                                                    ║"
echo "║                                                                  ║"
echo "║  2. Create Docker Hub secret (secure method):                    ║"
echo "║     read -p \"Docker Hub username: \" DOCKER_USER                 ║"
echo "║     read -sp \"Docker Hub password/token: \" DOCKER_PASS && echo  ║"
echo "║     kubectl create secret docker-registry dockerhub \\           ║"
echo "║       --docker-server=https://index.docker.io/v1/ \\             ║"
echo "║       --docker-username=\"\$DOCKER_USER\" \\                       ║"
echo "║       --docker-password=\"\$DOCKER_PASS\" \\                       ║"
echo "║       -n $ENV_DIR                                                ║"
echo "║     unset DOCKER_USER DOCKER_PASS                                ║"
echo "║                                                                  ║"
echo "║  3. Deploy the environment:                                      ║"
echo "║     ./deploy.sh                                                  ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
