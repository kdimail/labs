# Flux CD GitOps Repository

## 🏗️ Architecture Overview

This repository follows a **layered architecture** with clear separation of concerns:

```
flux/
├── clusters/           # Cluster-specific configs (Flux entry points)
├── infrastructure/     # Core K8s functionality (External Secrets, Ingress, etc.)
├── operators/          # Kubernetes operators/controllers
├── platform-services/  # Services that use operators (DBs, monitoring, messaging)
├── applications/       # Business applications
└── docs/              # Documentation
```

### 📦 Base + Overlay Pattern

Each layer uses the **base/overlay** pattern:
- **base/** - Common, reusable configurations
- **overlays/[env]/** - Environment-specific customizations

This eliminates code duplication and makes it easy to add new environments.

---

## 🚀 Deployment Flow

The deployment happens in **layers** with clear dependencies:

```
1. Infrastructure (External Secrets Operator)
           ↓
2. Operators (MongoDB, RabbitMQ, Prometheus)
           ↓
3. Platform Services (Monitoring, Headlamp, Databases, Messaging)
           ↓
4. Applications (Your apps)
```

Each layer waits for the previous one to be ready before deploying.

---

## 📂 Directory Structure Details

### **clusters/**
Entry points for each cluster. Contains Flux Kustomization CRs that tell Flux what to deploy.

```
clusters/
└── shared-non-prod/
    └── workloads/
        ├── infrastructure.yaml      # Deploys infrastructure layer
        ├── operators.yaml           # Deploys operators layer
        ├── platform-services.yaml   # Deploys platform services
        └── applications.yaml        # Deploys applications
```

### **infrastructure/**
Core Kubernetes functionality required by everything else.

```
infrastructure/
├── base/
│   └── external-secrets/           # External Secrets Operator
│       ├── namespace.yaml
│       ├── serviceaccount.yaml
│       ├── helmrepository.yaml
│       ├── helmrelease.yaml
│       ├── values.yaml
│       └── kustomization.yaml
│
└── overlays/
    └── shared-non-prod/
        └── kustomization.yaml      # Inherits from base
```

### **operators/**
Kubernetes operators that extend the API.

```
operators/
├── base/
│   ├── mongodb-operator/           # MongoDB Community Operator
│   ├── rabbitmq-operator/          # RabbitMQ Cluster Operator
│   └── prometheus-operator/        # Prometheus Operator (namespace + repo only)
│
└── overlays/
    └── shared-non-prod/
        └── kustomization.yaml      # Deploys all operators
```

### **platform-services/**
Services that depend on operators.

```
platform-services/
├── base/
│   ├── secret-stores/              # ClusterSecretStore (Azure Key Vault)
│   ├── monitoring/                 # Prometheus + Grafana
│   ├── headlamp/                   # Kubernetes Dashboard
│   ├── databases/
│   │   └── mongodb/                # MongoDB instances
│   └── messaging/
│       └── rabbitmq/               # RabbitMQ clusters
│
└── overlays/
    └── shared-non-prod/
        └── kustomization.yaml      # Deploys all services
```

### **applications/**
Your business applications.

```
applications/
├── base/
│   └── sample-app/
│       ├── deployment.yaml
│       ├── externalsecret.yaml
│       └── kustomization.yaml
│
└── overlays/
    └── shared-non-prod/
        └── kustomization.yaml
```

---

## 🎯 How to Use

### **View Current Structure**
```bash
cd flux/
tree -L 3 -d
```

### **Test a Component**
```bash
# Test a base component
kubectl apply --dry-run=server -k infrastructure/base/external-secrets/

# Test an overlay
kubectl apply --dry-run=server -k infrastructure/overlays/shared-non-prod/
```

### **Deploy a Layer**
```bash
# Infrastructure
kubectl apply -k clusters/shared-non-prod/workloads/infrastructure.yaml

# Operators
kubectl apply -k clusters/shared-non-prod/workloads/operators.yaml

# Platform Services
kubectl apply -k clusters/shared-non-prod/workloads/platform-services.yaml

# Applications
kubectl apply -k clusters/shared-non-prod/workloads/applications.yaml
```

### **Trigger Reconciliation**
```bash
# Reconcile a specific Kustomization
flux reconcile kustomization infrastructure --with-source

# Reconcile all
flux reconcile kustomization --all
```

### **Check Status**
```bash
# All Kustomizations
flux get kustomizations

# All HelmReleases
flux get helmreleases -A

# Specific component
kubectl get externalsecret -A
kubectl get rabbitmqcluster -A
```

---

## 🔧 Adding a New Environment

To add a new environment (e.g., `staging`):

1. **Create overlay directories:**
   ```bash
   mkdir -p infrastructure/overlays/staging
   mkdir -p operators/overlays/staging
   mkdir -p platform-services/overlays/staging
   mkdir -p applications/overlays/staging
   ```

2. **Create kustomization.yaml in each:**
   ```yaml
   ---
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization

   resources:
     - ../../base/[component-name]

   # Add staging-specific patches here
   ```

3. **Create cluster workloads:**
   ```bash
   mkdir -p clusters/staging/workloads
   # Copy and modify workload Kustomizations from shared-non-prod
   ```

---

## 📝 Adding a New Component

### Example: Adding Redis

1. **Create base directory:**
   ```bash
   mkdir -p platform-services/base/databases/redis
   ```

2. **Add manifests:**
   ```bash
   cd platform-services/base/databases/redis
   # Add: namespace.yaml, helmrelease.yaml, values.yaml, etc.
   # Add: kustomization.yaml
   ```

3. **Add to overlay:**
   ```yaml
   # platform-services/overlays/shared-non-prod/kustomization.yaml
   resources:
     # ... existing resources ...
     - ../../base/databases/redis
   ```

4. **Deploy:**
   ```bash
   flux reconcile kustomization platform-services --with-source
   ```

---

## 🎨 Benefits

### **For Developers:**
✅ **Predictable locations** - always know where to find things  
✅ **No deep paths** - max 3 levels deep  
✅ **DRY principle** - no code duplication  
✅ **Easy testing** - test components in isolation  

### **For Operations:**
✅ **Layer-by-layer deployment** - clear dependency order  
✅ **Selective updates** - update only what changed  
✅ **Fast troubleshooting** - isolated components  
✅ **Environment management** - easy to add/modify environments  

### **For the Team:**
✅ **Self-documenting** - structure explains itself  
✅ **Industry standard** - Flux best practices  
✅ **Fast onboarding** - new team members understand quickly  
✅ **Scalable** - grows with your needs  

---

## 📚 Documentation

See `/docs` for detailed documentation:
- Architecture diagrams
- Runbooks
- Azure AD setup guides
- Troubleshooting

---

## 🆘 Troubleshooting

### **Component not deploying?**
```bash
# Check Kustomization status
kubectl describe kustomization [name] -n flux-system

# Check HelmRelease status
kubectl describe helmrelease [name] -n [namespace]

# Check ExternalSecret status
kubectl describe externalsecret [name] -n [namespace]
```

### **Need to force reconciliation?**
```bash
# Force GitRepository refresh
flux reconcile source git shared-flux

# Force Kustomization refresh
flux reconcile kustomization infrastructure --with-source
```

### **Want to see what will be deployed?**
```bash
# Dry-run
kubectl apply --dry-run=server -k [path-to-kustomization]

# Preview with Flux
flux diff kustomization infrastructure --path ./flux/infrastructure/overlays/shared-non-prod
```

---

**For complete architecture details, see:**
- `ARCHITECTURE_IMPROVEMENT_PROPOSAL.md`
- `ARCHITECTURE_QUICK_COMPARISON.md`

**Questions? Open a discussion with the team!** 🚀

