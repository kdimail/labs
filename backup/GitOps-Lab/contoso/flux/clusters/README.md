# Flux Clusters

This directory contains the main entry points for each Kubernetes cluster managed by Flux CD.

## Structure

```
clusters/
└── ilc-shared-non-prod/          # Main entry point for shared non-prod cluster
    ├── kustomization.yaml        # Main Kustomization (references 4 layers)
    ├── infrastructure.yaml       # Layer 1: External Secrets Operator
    ├── operators.yaml            # Layer 2: MongoDB, RabbitMQ, Prometheus operators
    ├── platform-services.yaml    # Layer 3: Monitoring, Databases, Messaging
    └── applications.yaml         # Layer 4: Business applications
```

## Terraform Configuration

Update your Terraform to point to this new path:

```hcl
resource "azurerm_kubernetes_flux_configuration" "flux" {
  # ... other config ...
  
  kustomizations {
    name = "shared-flux"
    path = "./flux/clusters/ilc-shared-non-prod"  # ← New path
    # ... other config ...
  }
}
```

## Adding New Clusters

To add a new cluster (e.g., production):

```bash
# Copy the template
cp -r flux/clusters/ilc-shared-non-prod flux/clusters/prod

# Update the files to point to prod overlays
# Edit: infrastructure.yaml, operators.yaml, platform-services.yaml, applications.yaml
```

## Migration from Old Path

**Old path**: `./flux/infra/main/ilc-shared-non-prod/`  
**New path**: `./flux/clusters/ilc-shared-non-prod/`

The old directory can be removed after successful migration.

