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
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    log_error ".env file not found"
    echo "Copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    exit 1
fi

# Validate required variables
validate_required() {
    local missing=0
    for var in TAILSCALE_IP NAMESPACE DOMAIN POSTGRES_PASSWORD; do
        if [ -z "${!var}" ] || [ "${!var}" = "CHANGE_ME" ]; then
            log_error "Required variable $var is not set"
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        exit 1
    fi
}

validate_required

# Print configuration
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           Digital Tvilling Kubernetes Deployment                  ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  %-20s %-43s ║\n" "Environment:" "$ENVIRONMENT_NAME"
printf "║  %-20s %-43s ║\n" "Namespace:" "$NAMESPACE"
printf "║  %-20s %-43s ║\n" "Domain:" "$DOMAIN"
printf "║  %-20s %-43s ║\n" "Tailscale IP:" "$TAILSCALE_IP"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Service Profiles:                                               ║"
printf "║    %-18s %-42s ║\n" "DTI Services:" "${ENABLE_DTI_SERVICES:-true}"
printf "║    %-18s %-42s ║\n" "Frontend:" "${ENABLE_FRONTEND:-true}"
printf "║    %-18s %-42s ║\n" "Calcifer:" "${ENABLE_CALCIFER_SERVICES:-true}"
printf "║    %-18s %-42s ║\n" "Keel:" "${ENABLE_KEEL:-true}"
printf "║    %-18s %-42s ║\n" "DTI Auth:" "${ENABLE_DTI_AUTH:-false}"
printf "║    %-18s %-42s ║\n" "DTI Skala:" "${ENABLE_DTI_SKALA:-false}"
printf "║    %-18s %-42s ║\n" "DTSDT:" "${ENABLE_DTSDT:-false}"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Function to apply manifests from a directory
apply_manifests() {
    local dir=$1
    local name=$2
    
    if [ -d "manifests/$dir" ] && [ "$(ls -A manifests/$dir/*.yaml 2>/dev/null)" ]; then
        log_info "Applying $name manifests..."
        for file in manifests/$dir/*.yaml; do
            echo "  → $file"
            envsubst < "$file" | kubectl apply -f -
        done
    fi
}

# Always apply core manifests
apply_manifests "core" "Core infrastructure"

# Apply DTI services if enabled (integration components)
if [ "${ENABLE_DTI_SERVICES:-true}" = "true" ]; then
    apply_manifests "dti" "DTI services (Digital Twin Integration)"
fi

# Apply Frontend if enabled
if [ "${ENABLE_FRONTEND:-true}" = "true" ]; then
    apply_manifests "frontend" "Frontend"
fi

# Apply Calcifer services if enabled (includes extraction pipeline)
if [ "${ENABLE_CALCIFER_SERVICES:-true}" = "true" ]; then
    apply_manifests "calcifer" "Calcifer AI services"
fi

# Apply infrastructure services if enabled
if [ "${ENABLE_KEEL:-true}" = "true" ]; then
    apply_manifests "infrastructure" "Infrastructure services"
fi

# Apply optional services based on flags
if [ "${ENABLE_DTI_AUTH:-false}" = "true" ]; then
    if [ -f "manifests/optional/dti-authorization.yaml" ]; then
        log_info "Applying DTI Authorization..."
        envsubst < "manifests/optional/dti-authorization.yaml" | kubectl apply -f -
    fi
    if [ -f "manifests/optional/dti-auth-configs.yaml" ]; then
        envsubst < "manifests/optional/dti-auth-configs.yaml" | kubectl apply -f -
    fi
fi

if [ "${ENABLE_DTI_SKALA:-false}" = "true" ]; then
    if [ -f "manifests/optional/dti-skala.yaml" ]; then
        log_info "Applying DTI Skala..."
        envsubst < "manifests/optional/dti-skala.yaml" | kubectl apply -f -
    fi
fi

if [ "${ENABLE_DTSDT:-false}" = "true" ]; then
    for file in manifests/optional/dtsdt-*.yaml; do
        if [ -f "$file" ]; then
            log_info "Applying $(basename $file)..."
            envsubst < "$file" | kubectl apply -f -
        fi
    done
fi

echo ""
log_info "Restarting deployments to pull latest images..."

# Build list of deployments to restart based on enabled profiles
DEPLOYMENTS=""

if [ "${ENABLE_DTI_SERVICES:-true}" = "true" ]; then
    DEPLOYMENTS="$DEPLOYMENTS deployment/dti-core deployment/dti-partitur deployment/dti-ai"
fi

if [ "${ENABLE_FRONTEND:-true}" = "true" ]; then
    DEPLOYMENTS="$DEPLOYMENTS deployment/frontend"
fi

if [ "${ENABLE_CALCIFER_SERVICES:-true}" = "true" ]; then
    DEPLOYMENTS="$DEPLOYMENTS deployment/calcifer-mcp-server deployment/calcifer-server deployment/calcifer-gradio deployment/coding-mcp-server"
    DEPLOYMENTS="$DEPLOYMENTS deployment/extraction-orchestrator deployment/extraction-graph-interface deployment/extraction-calcifer-extractor deployment/extraction-rag-extractor deployment/extraction-entity-extractor"
fi

if [ "${ENABLE_DTI_AUTH:-false}" = "true" ]; then
    DEPLOYMENTS="$DEPLOYMENTS deployment/dti-authorization"
fi

if [ "${ENABLE_DTI_SKALA:-false}" = "true" ]; then
    DEPLOYMENTS="$DEPLOYMENTS deployment/dti-skala"
fi

if [ "${ENABLE_DTSDT:-false}" = "true" ]; then
    DEPLOYMENTS="$DEPLOYMENTS deployment/dtsdt-backend deployment/dtsdt-frontend deployment/dtsdt-mcp-server"
fi

# Restart deployments
if [ -n "$DEPLOYMENTS" ]; then
    kubectl rollout restart $DEPLOYMENTS -n $NAMESPACE 2>/dev/null || true
    
    log_info "Waiting for rollouts to complete..."
    for dep in $DEPLOYMENTS; do
        kubectl rollout status $dep -n $NAMESPACE --timeout=5m 2>/dev/null || log_warn "Timeout waiting for $dep"
    done
fi

echo ""
log_success "Deployment complete!"
echo ""
kubectl get pods -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE
