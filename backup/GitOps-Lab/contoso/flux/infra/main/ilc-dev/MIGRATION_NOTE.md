# ⚠️ DEPRECATED - This Directory Has Been Moved

## New Location

This directory has been moved to follow industry-standard Flux patterns:

**Old path**: `./flux/infra/main/ilc-shared-non-prod/`  
**New path**: `./flux/clusters/ilc-shared-non-prod/` ✅

## Why the Change?

1. **Industry Standard** - The `clusters/` pattern is used by Flux documentation and most repositories
2. **Clearer Purpose** - Makes it obvious this is a cluster entry point
3. **Scalable** - Easy to add more clusters: `clusters/prod/`, `clusters/staging/`
4. **Simpler** - Removes redundant `infra/main/` nesting

## Migration Steps

### 1. Update Terraform Configuration

```hcl
resource "azurerm_kubernetes_flux_configuration" "flux" {
  # ... other config ...
  
  kustomizations {
    name = "shared-flux"
    path = "./flux/clusters/ilc-shared-non-prod"  # ← Update this
    # ... other config ...
  }
}
```

### 2. Apply Terraform

```bash
terraform plan
terraform apply
```

### 3. Verify Flux Sync

```bash
kubectl get gitrepository shared-flux -n flux-system -o yaml | grep path
# Should show: path: ./contoso/flux/clusters/ilc-shared-non-prod
```

### 4. Remove This Directory

Once Terraform is updated and Flux is syncing from the new location, this directory can be safely deleted.

---

**Date**: January 7, 2026  
**Status**: Deprecated - Use `flux/clusters/ilc-shared-non-prod/` instead

