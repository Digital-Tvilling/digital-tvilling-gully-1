# Digital Tvilling Gully-1 (On-Premises Multi-Environment)

On-premises deployment of the Digital Tvilling platform on the **NVIDIA DGX Spark** server (gully-1). This repository contains **three separate environments** that can run simultaneously on the same server.

## 📍 Repository Location on Gully

On the Gully server, this repository should be cloned into **`/infra`** with shared access for all infrastructure users.

### Initial Setup (run once on the server)

```bash
# Create infraadmins group and add users
sudo groupadd infraadmins
sudo usermod -aG infraadmins filip
sudo usermod -aG infraadmins johanhanses
sudo usermod -aG infraadmins oliver

# Create /infra with shared group ownership
sudo mkdir -p /infra
sudo chown root:infraadmins /infra
sudo chmod 2775 /infra  # setgid ensures new files inherit group

# Clone the repo (any infraadmins user can do this after re-login)
cd /infra
git clone https://github.com/Digital-Tvilling/digital-tvilling-gully-1.git
```

> **Note:** Users need to log out and back in after being added to the `infraadmins` group.

This creates `/infra/digital-tvilling-gully-1/`. All `infraadmins` members can now manage deployments:

```bash
# Go to the infra folder
cd /infra/digital-tvilling-gully-1

# Update to latest
git pull

# Navigate to the environment you want to manage
cd gully-prod   # or gully-dev, gully-demo

# Run deployment scripts
./deploy.sh
./init.sh       # first-time setup only
./teardown.sh   # to remove environment
```

## 🖥️ Hardware

| Component | Specification |
|-----------|---------------|
| **Server** | NVIDIA DGX Spark |
| **GPU** | NVIDIA GPU with CUDA support |
| **Use Case** | On-premises AI/ML workloads, edge computing |
| **Network** | Local network + Tailscale for remote access |

## 📁 Multi-Environment Structure

This repository contains three independent environments, each in its own folder:

```
digital-tvilling-gully-1/
├── gully-prod/      # Production environment (stable tags)
├── gully-dev/       # Development environment (dev tags)
└── gully-demo/      # Demo environment (stable tags)
```

Each environment has:
- **Own namespace** in Kubernetes (isolated)
- **Own manifests** (can be customized per environment)
- **Own deploy scripts** (`deploy.sh`, `init.sh`, `teardown.sh`)
- **Own configuration** (`.env` file)

## 🎯 Environments

| Environment | Image Tags | Namespace | Domain | Purpose |
|-------------|------------|-----------|--------|---------|
| **gully-prod** | `stable` | `gully-prod` | `gully-prod` | Production workloads |
| **gully-dev** | `dev` | `gully-dev` | `gully-dev` | Development/testing |
| **gully-demo** | `stable` | `gully-demo` | `gully-demo` | Demos/presentations |

## 🚀 Quick Start

### 1. Initialize Server (First Time Only)

```bash
# Go to infra folder
cd /infra/digital-tvilling-gully-1/gully-prod

# Install K3s, kubectl, etc. (run once)
./init.sh
```

### 2. Configure Each Environment

For each environment you want to deploy:

```bash
# Production
cd /infra/digital-tvilling-gully-1/gully-prod
cp .env.example .env
nano .env  # Configure with your values

# Development
cd /infra/digital-tvilling-gully-1/gully-dev
cp .env.example .env
nano .env  # Configure with your values

# Demo
cd /infra/digital-tvilling-gully-1/gully-demo
cp .env.example .env
nano .env  # Configure with your values
```

**Key settings for each environment:**
```bash
# In each .env file
ENVIRONMENT_NAME=gully-prod  # or gully-dev, gully-demo
NAMESPACE=gully-prod         # or gully-dev, gully-demo
DOMAIN=gully-prod            # or gully-dev, gully-demo
TAILSCALE_IP=<your-tailscale-ip>

# Image tags are pre-configured in manifests:
# - gully-prod: uses :stable
# - gully-dev: uses :dev
# - gully-demo: uses :stable
```

### 3. Create Docker Hub Secret (Per Namespace)

```bash
# For each environment namespace
kubectl create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<token> \
  -n gully-prod

kubectl create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<token> \
  -n gully-dev

kubectl create secret docker-registry dockerhub \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<token> \
  -n gully-demo
```

### 4. Deploy Environments

Deploy each environment independently:

```bash
# Deploy production
cd /infra/digital-tvilling-gully-1/gully-prod
./deploy.sh

# Deploy development
cd /infra/digital-tvilling-gully-1/gully-dev
./deploy.sh

# Deploy demo
cd /infra/digital-tvilling-gully-1/gully-demo
./deploy.sh
```

### 5. Configure Tailscale DNS

Add DNS entries for each environment:

1. Go to https://login.tailscale.com/admin/dns
2. Add nameserver → Custom → Enter Tailscale IP
3. Restrict to domains: `gully-prod`, `gully-dev`, `gully-demo`
4. Save

## 🔗 Access

| Environment | Frontend URL | Namespace |
|-------------|--------------|-----------|
| Production | http://gully-prod | `gully-prod` |
| Development | http://gully-dev | `gully-dev` |
| Demo | http://gully-demo | `gully-demo` |

## 🔒 Security

All environments follow the same security model:
- **Only frontend exposed** via Ingress (Tailscale network)
- **All other services** are internal-only
- **GPU resources** available to Calcifer services
- **Isolated namespaces** prevent cross-environment access

## 📋 Commands

### Check Status

```bash
# Check all environments
kubectl get pods -A | grep gully

# Check specific environment
kubectl get pods -n gully-prod
kubectl get pods -n gully-dev
kubectl get pods -n gully-demo
```

### View Logs

```bash
# Production
kubectl logs -l app=frontend -n gully-prod

# Development
kubectl logs -l app=calcifer-server -n gully-dev
```

### Restart Services

```bash
# Restart production frontend
kubectl rollout restart deployment/frontend -n gully-prod

# Restart dev calcifer
kubectl rollout restart deployment/calcifer-server -n gully-dev
```

### Teardown

```bash
# Remove an environment
cd /infra/digital-tvilling-gully-1/gully-prod
./teardown.sh
```

## 🔧 GPU Configuration

The DGX Spark GPU is available to all environments. Each Calcifer server can request GPU resources:

```yaml
# In manifests/calcifer/04-server.yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

**Note:** If multiple environments need GPU simultaneously, ensure you have enough GPU resources or use node selectors/affinity to schedule appropriately.

## 📚 Related Repositories

- [digital-tvilling-k8s-template](https://github.com/Digital-Tvilling/digital-tvilling-k8s-template) - Base template
- [digital-tvilling-prod](https://github.com/Digital-Tvilling/digital-tvilling-prod) - Cloud production deployment
- [digital-tvilling-dev](https://github.com/Digital-Tvilling/digital-tvilling-dev) - Cloud development deployment

## 📄 License

Proprietary - Digital Tvilling
