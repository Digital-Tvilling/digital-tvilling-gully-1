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
```

> **Note:** Users need to log out and back in after being added to the `infraadmins` group.

### Set Up GitHub Deploy Key

Create a deploy key so Git can clone the private repository:

```bash
# Generate the deploy key (run as your user)
ssh-keygen -t ed25519 -C "deploy-key-gully-1" -f ~/.ssh/deploy_key -N ""

# Configure SSH to use this key for GitHub
cat >> ~/.ssh/config << EOF
Host github.com
  IdentityFile ~/.ssh/deploy_key
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

# Add GitHub's host key to known_hosts (avoids authenticity prompt)
ssh-keyscan github.com >> ~/.ssh/known_hosts

# Show the public key (copy this)
cat ~/.ssh/deploy_key.pub
```

**Add the key to GitHub:**
1. Go to [digital-tvilling-gully-1 repo](https://github.com/Digital-Tvilling/digital-tvilling-gully-1) → **Settings** → **Deploy keys** → **Add deploy key**
2. Title: `gully-1-server`
3. Paste the public key and save

### Clone the Repository

```bash
# Clone via SSH (any infraadmins user can do this after re-login)
cd /infra
git clone git@github.com:Digital-Tvilling/digital-tvilling-gully-1.git
```

This creates `/infra/digital-tvilling-gully-1/`. All `infraadmins` members can now manage deployments:

```bash
# Go to the infra folder
cd /infra/digital-tvilling-gully-1

# Update to latest
git pull

# Navigate to the environment you want to manage
cd gully-prod   # or gully-dev, gully-demo

# Run scripts
./init.sh       # first-time: creates .env
./deploy.sh     # deploy the environment
./teardown.sh   # remove the environment
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

Run the **root** `init.sh` to install K3s and tools:

```bash
cd /infra/digital-tvilling-gully-1

# Install K3s, kubectl, envsubst, tmux (run once)
./init.sh
```

### 2. Initialize Each Environment

For each environment, run its `init.sh` to create the `.env` file:

```bash
# Production
cd /infra/digital-tvilling-gully-1/gully-prod
./init.sh    # creates .env with defaults

# Development
cd /infra/digital-tvilling-gully-1/gully-dev
./init.sh

# Demo
cd /infra/digital-tvilling-gully-1/gully-demo
./init.sh
```

### 3. Configure Each Environment

Edit the `.env` file in each environment (created by `./init.sh`):

```bash
cd /infra/digital-tvilling-gully-1/gully-prod
nano .env  # Edit secrets and Tailscale IP
```

**Key settings to configure:**
```bash
# Already set by init.sh:
ENVIRONMENT_NAME=gully-prod
NAMESPACE=gully-prod
DOMAIN=gully-prod

# You need to set:
TAILSCALE_IP=<your-tailscale-ip>   # Run: tailscale ip -4
# ... and other secrets (Neo4j, MinIO, etc.)
```

### 4. Create Docker Hub Secret (Per Namespace)

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

### 5. Deploy Environments

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

### 6. Configure Tailscale DNS

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
