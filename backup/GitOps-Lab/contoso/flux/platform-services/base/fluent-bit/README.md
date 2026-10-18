# Fluent Bit - Production-Grade Log Collection

Production-grade Fluent Bit deployment using the official Helm chart for collecting logs from all pods and nodes in the Kubernetes cluster and forwarding them to Logstash.

## Overview

Fluent Bit is deployed as a DaemonSet (one pod per node) to collect:
- **Container logs** from all pods
- **Systemd logs** from kubelet service

All logs are enriched with Kubernetes metadata and sent to Logstash for processing and indexing into Elasticsearch.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │   Node 1   │  │   Node 2   │  │   Node N   │            │
│  │            │  │            │  │            │            │
│  │ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │            │
│  │ │ Fluent │ │  │ │ Fluent │ │  │ │ Fluent │ │            │
│  │ │  Bit   │ │  │ │  Bit   │ │  │ │  Bit   │ │            │
│  │ └───┬────┘ │  │ └───┬────┘ │  │ └───┬────┘ │            │
│  │     │      │  │     │      │  │     │      │            │
│  └─────┼──────┘  └─────┼──────┘  └─────┼──────┘            │
│        │                │                │                   │
│        └────────────────┴────────────────┘                   │
│                         │                                    │
│                         │ HTTP:8080 (JSON, gzipped)          │
│                         ▼                                    │
│              ┌─────────────────────┐                        │
│              │      Logstash       │                        │
│              │   (elastic-stack)   │                        │
│              └──────────┬──────────┘                        │
│                         │                                    │
│                         ▼                                    │
│              ┌─────────────────────┐                        │
│              │   Elasticsearch     │                        │
│              └──────────┬──────────┘                        │
│                         │                                    │
│                         ▼                                    │
│              ┌─────────────────────┐                        │
│              │       Kibana        │                        │
│              └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Helm Deployment

**HelmRepository:** `https://fluent.github.io/helm-charts`
**Chart:** `fluent-bit`
**Version:** `0.47.x`

### 2. Production Features

- ✅ **Filesystem buffering** for reliability
- ✅ **Automatic retry** on failures (5 retries)
- ✅ **Gzip compression** to reduce network traffic
- ✅ **Multi-worker output** for performance (2 workers)
- ✅ **Kubernetes metadata enrichment** (pod, namespace, labels)
- ✅ **Systemd log collection** (kubelet logs)
- ✅ **Health checks** and metrics
- ✅ **Prometheus monitoring** via ServiceMonitor
- ✅ **Self-filtering** (excludes own logs to prevent loops)

### 3. Resource Allocation

**Per Pod:**
- CPU Request: 100m
- CPU Limit: 500m
- Memory Request: 128Mi
- Memory Limit: 256Mi

**For 10 nodes:** ~1 CPU, ~1.28 GB RAM total

### 4. Log Enrichment

Each log entry includes:
- `@timestamp`: ISO8601 timestamp
- `message`: Original log content
- `k8s_pod_name`: Pod name
- `k8s_namespace_name`: Namespace
- `k8s_container_name`: Container name
- `k8s_node_name`: Node name
- `k8s_labels`: Pod labels
- `cluster_name`: "ilc-shared-non-prod"
- `environment`: "shared-non-prod"
- `log_source`: "fluent-bit"
- `hostname`: Node hostname

## Configuration

### Input Configuration

```ini
[INPUT]
    Name tail
    Path /var/log/containers/*.log
    multiline.parser docker, cri
    Tag kube.*
    Mem_Buf_Limit 5MB
    storage.type filesystem
```

### Filter Configuration

1. **Kubernetes Metadata Enrichment**
   - Adds pod, namespace, container info
   - Adds labels and annotations
   - Uses Kubelet for better performance

2. **Add Custom Fields**
   - cluster_name
   - environment
   - log_source

3. **Flatten Kubernetes Metadata**
   - Lifts nested kubernetes.* fields to k8s_*
   - Easier to query in Kibana

4. **Cleanup**
   - Rename "log" to "message"
   - Remove redundant fields

5. **Self-Filter**
   - Excludes logs from "logging" namespace
   - Prevents circular logging

### Output Configuration

```ini
[OUTPUT]
    Name http
    Match kube.*
    Host production-ls-ls-http.elastic-stack.svc.cluster.local
    Port 8080
    URI /
    Format json
    Compress gzip
    Workers 2
    Retry_Limit 5
    storage.total_limit_size 50M
```

## Monitoring

### Metrics Endpoint

Fluent Bit exposes Prometheus metrics:
- **Port:** 2020
- **Path:** `/api/v1/metrics/prometheus`

**Key Metrics:**
- `fluentbit_input_records_total` - Total records collected
- `fluentbit_output_records_total` - Total records sent
- `fluentbit_output_errors_total` - Output errors
- `fluentbit_output_retries_total` - Retry attempts
- `fluentbit_storage_*` - Storage metrics

### ServiceMonitor

Prometheus automatically scrapes Fluent Bit metrics via ServiceMonitor.

## Verification

### Check Pods

```bash
kubectl get pods -n logging
```
Expected: One fluent-bit pod per node in `Running` state

### Check Logs

```bash
kubectl logs -n logging -l app=fluent-bit --tail=20
```

### Check Metrics

```bash
kubectl port-forward -n logging -l app=fluent-bit 2020:2020
curl http://localhost:2020/api/v1/metrics/prometheus
```

### Verify Logs in Elasticsearch

```bash
kubectl exec -n elastic-stack production-es-es-coordinating-0 -- \
  curl -k -u "elastic:${ELASTIC_PASSWORD}" \
  "https://localhost:9200/logstash-*/_count?pretty"
```

### View in Kibana

1. Access Kibana: `https://kibana-shared-non-prod.${domain_filter}`
2. Go to **Discover**
3. Select **logstash-*** index pattern
4. Search: `cluster_name: "ilc-shared-non-prod"`

## Troubleshooting

### Pods Not Running

```bash
# Check pod status
kubectl get pods -n logging -l app=fluent-bit

# Check logs
kubectl logs -n logging -l app=fluent-bit --tail=50

# Check events
kubectl get events -n logging --sort-by='.lastTimestamp'
```

### No Logs in Elasticsearch

```bash
# 1. Check Fluent Bit is sending logs
kubectl logs -n logging -l app=fluent-bit | grep -i "output"

# 2. Check Logstash is receiving logs
kubectl logs -n elastic-stack production-ls-ls-0 | grep -i "new http connection"

# 3. Verify network connectivity
kubectl exec -n logging -l app=fluent-bit -- \
  curl -v http://production-ls-ls-http.elastic-stack.svc.cluster.local:8080
```

### High Memory Usage

Adjust buffer limits in `values-cm.yaml`:

```yaml
Mem_Buf_Limit 10MB  # Increase from 5MB
storage.backlog.mem_limit 20M  # Increase from 10M
```

### High CPU Usage

Reduce log collection frequency:

```yaml
Refresh_Interval 30  # Increase from 10 seconds
```

## Configuration Changes

To modify Fluent Bit configuration:

1. Edit `values-cm.yaml` (ConfigMap with Helm values)
2. Commit and push changes
3. Flux will automatically reconcile

Or manually trigger:
```bash
flux reconcile helmrelease fluent-bit -n flux-system
```

## Security

- ✅ Runs as root (required to read container logs)
- ✅ Read-only root filesystem
- ✅ Drops all capabilities except `DAC_READ_SEARCH`
- ✅ No privilege escalation
- ✅ RBAC with minimal permissions

## Performance Tuning

### For High Log Volume

```yaml
# In values-cm.yaml, adjust:
Workers 4  # Increase parallel workers
Mem_Buf_Limit 10MB  # Increase buffer
storage.total_limit_size 100M  # Increase storage limit
Flush 5  # Increase flush interval
```

### For Low Resources

```yaml
# Reduce resource usage:
Workers 1  # Single worker
Mem_Buf_Limit 3MB  # Smaller buffer
Refresh_Interval 30  # Less frequent scanning
```

## Helm Chart Details

**Official Chart:** `https://github.com/fluent/helm-charts/tree/main/charts/fluent-bit`

**Advantages over raw manifests:**
- ✅ Battle-tested configuration
- ✅ Regular updates and security patches
- ✅ Built-in best practices
- ✅ Easy upgrades via Flux
- ✅ Comprehensive configuration options

## Files

- `namespace.yaml` - Creates `logging` namespace
- `helmrepository.yaml` - Fluent Helm repository
- `helmrelease.yaml` - Fluent Bit Helm release
- `values-cm.yaml` - Configuration ConfigMap (main config)
- `values.yaml` - Reference values (not deployed)
- `kibana-index-pattern-job.yaml` - Auto-creates Kibana index pattern
- `kustomization.yaml` - Kustomize orchestration
- `README.md` - This file

## Next Steps

1. **Create Custom Dashboards** in Kibana for your applications
2. **Set up Log-based Alerts** in Elasticsearch/Kibana
3. **Configure Log Retention** based on compliance requirements
4. **Add Application-Specific Parsing** in Logstash
5. **Enable Log Sampling** for very high-volume applications

## References

- [Fluent Bit Official Docs](https://docs.fluentbit.io/)
- [Fluent Bit Helm Chart](https://github.com/fluent/helm-charts)
- [Fluent Bit Kubernetes Filter](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes)
- [Fluent Bit HTTP Output](https://docs.fluentbit.io/manual/pipeline/outputs/http)
