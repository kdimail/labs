# Elastic Stack (ELK + APM)

Production-grade deployment of the complete Elastic Stack including Elasticsearch, Logstash, Kibana, and APM Server using the ECK (Elastic Cloud on Kubernetes) operator.

## Overview

This deployment provides a complete observability platform for:
- **Log Management** (Elasticsearch + Logstash + Kibana)
- **Application Performance Monitoring** (APM Server)
- **Real User Monitoring** (RUM via APM)
- **Distributed Tracing** (Jaeger integration)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         elastic-stack                                │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                   Elasticsearch Cluster                       │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐             │  │
│  │  │  Master    │  │  Master    │  │  Master    │             │  │
│  │  │  Node      │  │  Node      │  │  Node      │             │  │
│  │  │  (3)       │  │  (3)       │  │  (3)       │             │  │
│  │  └────────────┘  └────────────┘  └────────────┘             │  │
│  │                                                                │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐             │  │
│  │  │  Data      │  │  Data      │  │  Data      │             │  │
│  │  │  Node      │  │  Node      │  │  Node      │             │  │
│  │  │  (200GB)   │  │  (200GB)   │  │  (200GB)   │             │  │
│  │  └────────────┘  └────────────┘  └────────────┘             │  │
│  │                                                                │  │
│  │  ┌────────────┐  ┌────────────┐                              │  │
│  │  │Coordinating│  │Coordinating│                              │  │
│  │  │  Node      │  │  Node      │                              │  │
│  │  └────────────┘  └────────────┘                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              ▲                                       │
│                              │                                       │
│  ┌──────────────┬────────────┴───────────┬──────────────┐          │
│  │              │                        │              │          │
│  │  ┌──────────▼─────────┐  ┌──────────▼─────────┐   │          │
│  │  │      Kibana        │  │      Kibana        │   │          │
│  │  │   (Visualization)  │  │   (Visualization)  │   │          │
│  │  └────────────────────┘  └────────────────────┘   │          │
│  │              │                                       │          │
│  │  ┌──────────▼─────────────────────────────────┐   │          │
│  │  │          Logstash (3 nodes)                 │   │          │
│  │  │  - Beats input (5044)                       │   │          │
│  │  │  - HTTP input (8080)                        │   │          │
│  │  │  - Processing & filtering                   │   │          │
│  │  └─────────────────────────────────────────────┘   │          │
│  │                                                      │          │
│  │  ┌─────────────────────────────────────────────┐   │          │
│  │  │        APM Server (2 nodes)                  │   │          │
│  │  │  - Application tracing                       │   │          │
│  │  │  - RUM (Real User Monitoring)                │   │          │
│  │  │  - Jaeger integration                        │   │          │
│  │  └─────────────────────────────────────────────┘   │          │
│  │                                                      │          │
└──┴──────────────────────────────────────────────────────┴──────────┘
        ▲                   ▲                      ▲
        │                   │                      │
   [Ingress:           [Ingress:             [Ingress: APM]
    Kibana]             Logstash]            apm-shared-non-prod.${domain_filter}
   kibana-shared-non-prod.${domain_filter}  logstash-shared-non-prod.${domain_filter}
```

### Multi-Cluster Logging

Logstash is exposed via Ingress to accept logs from other Kubernetes clusters:

- **URL**: `https://logstash-shared-non-prod.${domain_filter}`
- **Port**: 443 (HTTPS)
- **Authentication**: Optional Basic Auth
- **Use Case**: Centralized logging from multiple clusters

See [MULTI_CLUSTER_LOGGING.md](./MULTI_CLUSTER_LOGGING.md) for detailed setup instructions.

## Components

### 1. Elasticsearch Cluster (8 nodes)

Production-grade multi-node cluster with dedicated roles:

#### Master Nodes (3 replicas)
- **Purpose**: Cluster coordination, index management, shard allocation
- **Resources**: 1-2 CPU, 2Gi RAM
- **Storage**: 50Gi per node
- **HA**: Required anti-affinity across nodes

#### Data Nodes (3 replicas)
- **Purpose**: Store data, execute queries, handle indexing
- **Resources**: 2-4 CPU, 8Gi RAM
- **Storage**: 200Gi per node (600Gi total)
- **HA**: Required anti-affinity across nodes

#### Coordinating Nodes (2 replicas)
- **Purpose**: Load balancing, query coordination, aggregation
- **Resources**: 1-2 CPU, 4Gi RAM
- **Storage**: 10Gi per node
- **HA**: Preferred anti-affinity

**Features:**
- TLS enabled for HTTP and transport
- Memory mapping disabled for AKS compatibility
- Pod disruption budget (minAvailable: 2)
- Premium SSD storage

### 2. Kibana (2 replicas)

Web interface for Elasticsearch data visualization and management.

**Features:**
- High availability with 2 replicas
- Encryption keys from Azure Key Vault
- X-Pack features enabled:
  - Reporting
  - Canvas
  - Graph
  - Machine Learning
- Session management (1h idle, 8h max)
- Resources: 500m-2 CPU, 2-4Gi RAM

**Access:**
- Internal: `https://production-kb-kb-http.elastic-stack.svc:5601`
- External: `https://kibana.yourdomain.com` (via Ingress)

### 3. Logstash (3 replicas)

Log processing and transformation pipeline.

**Features:**
- Persisted queue (4GB) for reliability
- Multiple input plugins:
  - Beats input (port 5044)
  - HTTP input (port 8080)
- Processing pipeline:
  - JSON parsing
  - Grok patterns for log parsing
  - Date extraction
- Output to Elasticsearch with ILM
- Resources: 1-2 CPU, 4Gi RAM
- Storage: 50Gi per node for queue
- **External Ingress** for multi-cluster logging

**Endpoints:**
- Beats (internal): `production-ls-ls-beats.elastic-stack.svc:5044`
- HTTP (internal): `production-ls-ls-http.elastic-stack.svc:8080`
- HTTP (external): `https://logstash-shared-non-prod.${domain_filter}` (via Ingress, for multi-cluster logging)

### 4. APM Server (2 replicas)

Application Performance Monitoring and distributed tracing.

**Features:**
- Real User Monitoring (RUM) enabled
- API key authentication
- Jaeger integration (gRPC: 14250, HTTP: 14268)
- Data streams for efficient storage
- Source map support
- Resources: 500m-1 CPU, 1-2Gi RAM

**Endpoints:**
- APM: `https://production-apm-apm-http.elastic-stack.svc:8200`
- External: `https://apm.yourdomain.com` (via Ingress)
- Jaeger gRPC: `production-apm-apm-http.elastic-stack.svc:14250`
- Jaeger HTTP: `production-apm-apm-http.elastic-stack.svc:14268`

## Security

### 1. TLS/SSL
- All components use TLS (self-signed certificates by ECK)
- HTTP and transport layers encrypted
- Ingress with Let's Encrypt certificates

### 2. Authentication
- Elasticsearch: Built-in users (elastic, kibana_system, etc.)
- APM: API key authentication + secret token
- Kibana: Elasticsearch authentication

### 3. Secrets Management
- Encryption keys from Azure Key Vault via External Secrets
- APM secret token from Azure Key Vault
- Automatic secret rotation

### 4. Network Policies
- Elasticsearch: Allow from Kibana, Logstash, APM only
- Kibana: Allow from Ingress controller only
- APM: Allow from Ingress and application namespaces
- Logstash: Allow Beats/HTTP from specific namespaces

## Azure Key Vault Secrets

Required secrets in Azure Key Vault:

```bash
# Kibana encryption key (32+ character random string)
az keyvault secret set --vault-name <vault-name> \
  --name kibana-encryption-key \
  --value "$(openssl rand -base64 32)"

# APM secret token
az keyvault secret set --vault-name <vault-name> \
  --name apm-secret-token \
  --value "$(openssl rand -base64 32)"
```

Or use the provided script:
```bash
./setup-keyvault-secrets.sh
```

## Resource Requirements

### Total Cluster Resources

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|-------------|-----------|----------------|--------------|---------|
| ES Master (x3) | 3 | 6 | 6Gi | 6Gi | 150Gi |
| ES Data (x3) | 6 | 12 | 24Gi | 24Gi | 600Gi |
| ES Coord (x2) | 2 | 4 | 8Gi | 8Gi | 20Gi |
| Kibana (x2) | 1 | 4 | 4Gi | 8Gi | - |
| Logstash (x3) | 3 | 6 | 12Gi | 12Gi | 150Gi |
| APM (x2) | 1 | 2 | 2Gi | 4Gi | - |
| **Total** | **16 CPU** | **34 CPU** | **56Gi** | **62Gi** | **920Gi** |

### Node Pool Recommendation

For optimal performance:
- **3-5 worker nodes** with:
  - 8 CPU cores minimum
  - 32Gi RAM minimum
  - Premium SSD storage
- **Node affinity** configured for data nodes on larger nodes

## Deployment

### Prerequisites

1. ECK operator installed and running:
```bash
kubectl get pods -n elastic-system
```

2. Azure Key Vault secrets configured
3. ClusterSecretStore configured
4. Ingress controller with cert-manager
5. Sufficient cluster resources

### Deploy via Flux

The stack is deployed automatically via Flux:

```bash
# Check deployment status
flux get kustomizations

# Force reconciliation
flux reconcile kustomization platform-services --with-source

# Watch Elasticsearch cluster startup
kubectl get elasticsearch -n elastic-stack -w

# Check all components
kubectl get elastic -n elastic-stack
```

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n elastic-stack

# Check Elasticsearch cluster health
kubectl exec -it -n elastic-stack production-es-es-master-0 -- \
  curl -k -u elastic:$PASSWORD https://localhost:9200/_cluster/health?pretty

# Get Elasticsearch password
PASSWORD=$(kubectl get secret -n elastic-stack production-es-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d)
echo $PASSWORD

# Check Kibana
kubectl get kibana -n elastic-stack

# Check APM Server
kubectl get apmserver -n elastic-stack

# Check Logstash
kubectl get logstash -n elastic-stack
```

## Usage

### Access Kibana

1. **Via Ingress** (external):
```
https://kibana.yourdomain.com
Username: elastic
Password: <from secret>
```

2. **Via Port Forward** (internal):
```bash
kubectl port-forward -n elastic-stack svc/production-kb-kb-http 5601:5601
https://localhost:5601
```

### Send Logs to Logstash

#### Via Beats
```yaml
output.logstash:
  hosts: ["production-ls-ls-beats.elastic-stack.svc:5044"]
```

#### Via HTTP
```bash
curl -X POST https://production-ls-ls-http.elastic-stack.svc:8080 \
  -H "Content-Type: application/json" \
  -d '{"message":"Test log","level":"info"}'
```

### Instrument Application with APM

#### Node.js
```javascript
const apm = require('elastic-apm-node').start({
  serviceName: 'my-app',
  serverUrl: 'https://apm.yourdomain.com',
  secretToken: '<apm-secret-token>'
})
```

#### Python
```python
from elasticapm import Client

client = Client({
    'SERVICE_NAME': 'my-app',
    'SERVER_URL': 'https://apm.yourdomain.com',
    'SECRET_TOKEN': '<apm-secret-token>'
})
```

#### Java
```properties
elastic.apm.service_name=my-app
elastic.apm.server_urls=https://apm.yourdomain.com
elastic.apm.secret_token=<apm-secret-token>
```

### Configure Jaeger Integration

```yaml
# In your Jaeger configuration
spec:
  collector:
    config: |
      receivers:
        jaeger:
          protocols:
            grpc:
              endpoint: production-apm-apm-http.elastic-stack.svc:14250
```

## Index Lifecycle Management (ILM)

Elasticsearch ILM policies manage index lifecycle:

```bash
# Create ILM policy for logs
kubectl exec -it -n elastic-stack production-es-es-master-0 -- \
  curl -k -u elastic:$PASSWORD -X PUT \
  "https://localhost:9200/_ilm/policy/logstash-policy?pretty" \
  -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "1d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "freeze": {}
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'
```

## Monitoring

### Built-in Monitoring

Kibana has built-in monitoring for the Elastic Stack:
1. Navigate to **Stack Monitoring** in Kibana
2. View cluster health, node stats, index stats
3. Monitor APM Server and Logstash

### Prometheus Integration

ECK exposes Prometheus metrics:

```yaml
# ServiceMonitor for Elasticsearch
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: elasticsearch
  namespace: elastic-stack
spec:
  selector:
    matchLabels:
      elasticsearch.k8s.elastic.co/cluster-name: production-es
  endpoints:
    - port: https
      path: /_prometheus/metrics
```

## Backup and Restore

### Snapshot Repository

Configure Azure Blob Storage for snapshots:

```bash
# Create repository
kubectl exec -it -n elastic-stack production-es-es-master-0 -- \
  curl -k -u elastic:$PASSWORD -X PUT \
  "https://localhost:9200/_snapshot/azure_backup?pretty" \
  -H 'Content-Type: application/json' -d'
{
  "type": "azure",
  "settings": {
    "container": "elasticsearch-snapshots",
    "base_path": "production",
    "compress": true
  }
}'

# Create snapshot
curl -k -u elastic:$PASSWORD -X PUT \
  "https://localhost:9200/_snapshot/azure_backup/snapshot_1?wait_for_completion=true"
```

## Troubleshooting

### Elasticsearch Not Starting

```bash
# Check pod events
kubectl describe pod -n elastic-stack production-es-es-master-0

# Check logs
kubectl logs -n elastic-stack production-es-es-master-0

# Common issues:
# 1. Insufficient resources
# 2. vm.max_map_count not set (handled by init container)
# 3. Storage not available
```

### Kibana Not Connecting to Elasticsearch

```bash
# Check Kibana logs
kubectl logs -n elastic-stack production-kb-kb-0

# Verify Elasticsearch is healthy
kubectl get elasticsearch -n elastic-stack

# Check service connectivity
kubectl exec -it -n elastic-stack production-kb-kb-0 -- \
  curl -k https://production-es-es-http:9200
```

### APM Server Not Receiving Data

```bash
# Check APM logs
kubectl logs -n elastic-stack production-apm-apm-server-0

# Verify secret token
kubectl get secret -n elastic-stack apm-server-credentials -o yaml

# Test connectivity
curl -k https://apm.yourdomain.com
```

### Logstash Pipeline Issues

```bash
# Check Logstash logs
kubectl logs -n elastic-stack production-ls-ls-0

# View pipeline stats
kubectl exec -it -n elastic-stack production-ls-ls-0 -- \
  curl http://localhost:9600/_node/stats/pipelines?pretty
```

## Scaling

### Scale Elasticsearch Data Nodes

```bash
# Edit elasticsearch.yaml
# Change data node count: 3 → 5
kubectl edit elasticsearch production-es -n elastic-stack
```

### Scale Logstash

```bash
# Edit logstash.yaml
# Change count: 3 → 5
kubectl edit logstash production-ls -n elastic-stack
```

### Scale Kibana

```bash
# Edit kibana.yaml
# Change count: 2 → 3
kubectl edit kibana production-kb -n elastic-stack
```

## Performance Tuning

### Elasticsearch

1. **JVM Heap**: Set to 50% of pod memory (already configured)
2. **Shard Strategy**: 20-40GB per shard for logs
3. **Refresh Interval**: Increase for better indexing performance
4. **Replica Count**: 1-2 replicas for production

### Logstash

1. **Queue Size**: Already set to 4GB persisted
2. **Workers**: Set based on CPU cores
3. **Batch Size**: Tune based on throughput

### Kibana

1. **Memory**: Increase for large dashboards
2. **Concurrent Requests**: Tune Elasticsearch.hosts

## References

- [ECK Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)
- [Elasticsearch Reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Guide](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Logstash Reference](https://www.elastic.co/guide/en/logstash/current/index.html)
- [APM Server Reference](https://www.elastic.co/guide/en/apm/server/current/index.html)
- [Production Best Practices](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-production-readiness.html)
