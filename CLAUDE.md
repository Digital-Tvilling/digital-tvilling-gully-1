# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Gully-1** is an on-premises deployment of the Digital Tvilling platform running on an **NVIDIA DGX Spark** server. This is the first on-prem installation, designed for edge computing with GPU-accelerated AI workloads.

Key characteristics:
- **On-premises**: Runs locally on DGX Spark hardware
- **GPU-enabled**: NVIDIA GPU available for Calcifer AI services
- **Hybrid architecture**: Local compute with cloud services (Neo4j, MinIO, MQTT)
- **Tailscale networking**: Private network access for remote management

## Commands

```bash
# Initialize server (installs K3s, kubectl, creates .env)
./init.sh

# Deploy all enabled services
./deploy.sh

# Remove all deployed resources
./teardown.sh

# Check deployment status
kubectl get pods -n digital-tvilling-gully-1
kubectl get ingress -n digital-tvilling-gully-1

# Check GPU status
nvidia-smi
kubectl get nodes -o json | jq '.items[].status.capacity'
```

## Architecture

**Environment Configuration (.env)**
- `ENVIRONMENT_NAME=gully-1`: Environment identifier
- `NAMESPACE=digital-tvilling-gully-1`: Kubernetes namespace
- `DOMAIN=gully-1`: Base domain for services
- `TAILSCALE_IP`: Server's Tailscale IP (`tailscale ip -4`)
- `ENABLE_GPU=true`: Enable GPU resources for AI workloads
- `IMAGE_TAG_SUFFIX`: Docker image tag suffix

**Hardware**
- Server: NVIDIA DGX Spark
- GPU: NVIDIA GPU with CUDA support
- Network: Local + Tailscale overlay

**Manifest Organization (manifests/)**
- `core/`: Always deployed (namespace, storage, postgres, dns)
- `dti/`: DTI application services (core, partitur, ai)
- `frontend/`: Web application
- `calcifer/`: Calcifer AI services with GPU support
- `infrastructure/`: Keel auto-updater
- `optional/`: Optional services (dti-auth, dti-skala, dtsdt)

**Service Profiles**
| Flag | Services | Default |
|------|----------|---------|
| `ENABLE_DTI_SERVICES` | dti-core, dti-partitur, dti-ai | true |
| `ENABLE_FRONTEND` | frontend | true |
| `ENABLE_CALCIFER_SERVICES` | calcifer-server (GPU), gradio, mcp-servers | true |
| `ENABLE_EXTRACTION_PIPELINE` | Full extraction pipeline | true |
| `ENABLE_KEEL` | Keel auto-updater | true |
| `ENABLE_DTI_AUTH` | dti-authorization | false |
| `ENABLE_DTI_SKALA` | dti-skala | false |
| `ENABLE_DTSDT` | dtsdt-backend, dtsdt-frontend, dtsdt-mcp | false |

**Networking Pattern**
- All services route through Tailscale IP
- DNS wildcard resolution maps `*.gully-1` to Tailscale node
- Ingress resources handle HTTP routing based on host headers
- Services communicate internally via Kubernetes DNS

## GPU Configuration

The DGX Spark GPU is exposed to Kubernetes via NVIDIA Container Toolkit. Calcifer services can request GPU resources:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

To verify GPU availability:
```bash
kubectl describe node | grep -A5 "Capacity:"
```

## Key Files

| File | Purpose |
|------|---------|
| `.env.example` | Template for all environment variables |
| `deploy.sh` | Main deployment script with profile support |
| `init.sh` | Server initialization (K3s, kubectl, etc.) |
| `teardown.sh` | Clean removal of all resources |
| `manifests/calcifer/04-server.yaml` | Calcifer server with GPU support |
| `manifests/core/02-postgres.yaml` | Main PostgreSQL with TimescaleDB |

## Common Tasks

**Check GPU utilization:**
```bash
nvidia-smi
watch -n 1 nvidia-smi
```

**Enable optional service:**
```bash
# In .env
ENABLE_DTI_AUTH=true

# Redeploy
./deploy.sh
```

**Restart Calcifer to pick up new GPU config:**
```bash
kubectl rollout restart deployment calcifer-server -n digital-tvilling-gully-1
```

## Differences from Cloud Deployments

| Aspect | Cloud (prod/dev) | On-Prem (gully-1) |
|--------|------------------|-------------------|
| GPU | Not available | NVIDIA DGX Spark |
| Network | Public DNS + TLS | Tailscale private |
| Storage | Cloud volumes | Local storage |
| External services | Direct access | Via Tailscale/VPN |
