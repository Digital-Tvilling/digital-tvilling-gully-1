#!/bin/bash
set -e

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    log_warn ".env file not found, using default namespace"
    NAMESPACE=${NAMESPACE:-digital-tvilling}
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║               Digital Tvilling - Teardown                        ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  Namespace: %-52s ║\n" "$NAMESPACE"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Confirm deletion
read -p "Are you sure you want to delete all resources in namespace '$NAMESPACE'? (y/N) " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

log_info "Removing resources from namespace: $NAMESPACE"
echo ""

# Delete optional services first
for file in manifests/optional/*.yaml; do
    if [ -f "$file" ]; then
        echo "  ← Deleting $(basename $file)..."
        envsubst < "$file" | kubectl delete -f - --ignore-not-found 2>/dev/null || true
    fi
done

# Delete in reverse directory order
for dir in infrastructure extraction calcifer dti core; do
    if [ -d "manifests/$dir" ]; then
        for file in $(ls -r manifests/$dir/*.yaml 2>/dev/null); do
            echo "  ← Deleting $(basename $file)..."
            envsubst < "$file" | kubectl delete -f - --ignore-not-found 2>/dev/null || true
        done
    fi
done

echo ""
log_success "Teardown complete!"
echo ""
log_info "Note: PersistentVolumeClaims may need manual deletion if data retention is not required:"
echo "  kubectl delete pvc --all -n $NAMESPACE"
echo ""
log_info "To delete the namespace entirely:"
echo "  kubectl delete namespace $NAMESPACE"
