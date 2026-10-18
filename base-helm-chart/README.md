# Base Helm Chart for Microservices

This repository contains a base Helm chart designed to be reused across multiple microservices.

## Structure

```
base-helm-chart/
├── base/                          # Base Helm chart
│   ├── Chart.yaml                 # Chart metadata
│   ├── values.yaml                # Default values
│   └── templates/                 # Kubernetes templates
│       ├── _helpers.tpl           # Template helpers
│       ├── deployment.yaml        # Deployment template
│       └── service.yaml           # Service template
├── dev-values.yaml                # Example values for development
├── helmrelease-example.yaml       # FluxCD HelmRelease example
└── temp/                          # Original example files
    ├── deployment.yaml
    └── service.yaml
```

## Usage

### 1. Local Development with Helm

Install the chart locally with custom values:

```bash
# Using dev-values.yaml
helm install contoso-purchase-backend ./base -f dev-values.yaml

# Or with inline values
helm install my-service ./base \
  --set image.registry=myregistry.azurecr.io \
  --set image.repository=my-service \
  --set image.tag=v1.0.0 \
  --set replicaCount=3
```

### 2. Using with FluxCD GitOps

The `helmrelease-example.yaml` file shows how to reference this base chart from your FluxCD GitOps repository.

#### Prerequisites

1. Create a GitRepository resource pointing to this repo:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: base-helm-chart
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/your-org/base-helm-chart  # Update with your repo URL
  ref:
    branch: main
```

2. Apply the GitRepository:

```bash
kubectl apply -f gitrepository.yaml
```

3. Use the HelmRelease to deploy your service:

```bash
kubectl apply -f helmrelease-example.yaml
```

### 3. Creating Values for New Microservices

Copy and modify `dev-values.yaml` for each new microservice:

```yaml
nameOverride: "my-new-service-api"
fullnameOverride: "my-new-service"

replicaCount: 2

image:
  registry: "myregistry.azurecr.io"
  repository: "my-new-service"
  tag: "v1.0.0"

# ... customize other values as needed
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.registry` | Container registry | `""` |
| `image.repository` | Image repository | `""` |
| `image.tag` | Image tag | `Chart.AppVersion` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `containerPort` | Container port | `80` |
| `env` | Static environment variables | `[]` |
| `envFromSecrets` | Environment variables from secrets | `[]` |
| `envFrom.configMapRef` | ConfigMap references | `[]` |
| `serviceAccountName` | Pod-level ServiceAccount (e.g. Workload Identity) | `""` |

### Health Probes

All health probes (startup, liveness, readiness) can be configured or disabled:

```yaml
startupProbe:
  enabled: true
  httpGet:
    path: /health/startup
    port: 80
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 30
```

### Environment Variables

#### Static Variables

```yaml
env:
  - name: MY_VAR
    value: "my-value"
  - name: ANOTHER_VAR
    value: "another-value"
```

#### From Secrets

```yaml
envFromSecrets:
  - name: DATABASE_PASSWORD
    secretName: db-credentials
    secretKey: password
```

#### From ConfigMaps

```yaml
envFrom:
  configMapRef:
    - name: app-config
```

### Init Containers

Raw pass-through, same convention as `volumes`/`volumeMounts` (also supported, undocumented here since they need no chart-specific shape):

```yaml
initContainers:
  - name: build-ca-bundle
    image: "same-registry/same-repo@sha256:..."
    command: ["sh", "-c"]
    args: ["..."]
    volumeMounts:
      - name: some-volume
        mountPath: /some/path
```

## Testing

Test the chart rendering locally:

```bash
# Render templates with default values
helm template ./base

# Render with dev values
helm template contoso-purchase-backend ./base -f dev-values.yaml

# Debug mode
helm template contoso-purchase-backend ./base -f dev-values.yaml --debug
```

## FluxCD Integration

The chart is designed to work seamlessly with FluxCD v2:

1. **GitRepository**: Points to this chart repository
2. **HelmRelease**: Deploys the chart with custom values
3. **Value Overrides**: Can be inline or from ConfigMaps/Secrets

See `helmrelease-example.yaml` for a complete example.

## Best Practices

1. **Version Control**: Tag your chart versions in Git
2. **Value Files**: Maintain separate value files per environment (dev, staging, prod)
3. **Secrets**: Never commit secrets - use Kubernetes Secrets or external secret managers
4. **Resource Limits**: Always set resource requests and limits in production
5. **Health Checks**: Configure appropriate health check paths for your application

## License

This chart is provided as-is for internal use.