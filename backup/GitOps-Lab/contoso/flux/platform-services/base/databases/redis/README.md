# Redis HA with Sentinel (Production Grade)

Production-grade Redis deployment using DandyDeveloper redis-ha Helm chart with Sentinel for automatic failover and **all secrets from Azure Key Vault**.

## Chart Information

- **Chart**: DandyDeveloper/redis-ha
- **Repository**: https://dandydeveloper.github.io/charts
- **Version**: >=4.26.0
- **Redis Version**: 7.2.4-alpine

## Architecture

```
┌──────────────────────────────────────────────────┐
│  Applications                                     │
│  redis-ha-haproxy.redis.svc.cluster.local:6379  │
└────────────────┬─────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────┐
│  HAProxy (3 replicas)                            │
│  - Load balancing                                │
│  - Connection pooling                            │
│  - Health checks every 2s                        │
└────────────────┬─────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────┐
│  Sentinel Cluster (3 replicas)                   │
│  - Monitors Redis master and replicas            │
│  - Detects failures (5s timeout)                 │
│  - Automatic failover (quorum: 2)                │
│  - Promotes replica to master                    │
└────────────────┬─────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────┐
│  Redis Cluster (3 replicas)                      │
│  - 1 master (automatic)                          │
│  - 2 replicas (automatic replication)            │
│  - AOF + RDB persistence                         │
│  - 10Gi storage per instance                     │
└──────────────────────────────────────────────────┘
```

## Components

### 1. Redis Pods (3 replicas)
- **Master**: Automatically elected by Sentinel
- **Replicas**: Automatically configured
- **Image**: `redis:7.2.4-alpine`
- **Persistence**: AOF (every second) + RDB snapshots
- **Storage**: 10Gi per instance (30Gi total)
- **Memory**: 512Mi-1Gi per pod (1GB max with LRU eviction)
- **CPU**: 250m-1000m per pod

### 2. Sentinel Pods (3 replicas)
- **Quorum**: 2 (requires 2 Sentinels to agree on failover)
- **Down after**: 5 seconds
- **Failover timeout**: 10 seconds
- **Parallel syncs**: 1 (one replica syncs at a time)
- **Memory**: 128Mi-256Mi per pod
- **CPU**: 100m-500m per pod

### 3. HAProxy Pods (3 replicas)
- **Purpose**: Load balancing and connection pooling
- **Health checks**: Every 2 seconds
- **Check fall**: 3 failures to mark down
- **Check rise**: 2 successes to mark up
- **Memory**: 128Mi-256Mi per pod
- **CPU**: 100m-500m per pod

### 4. Redis Exporter (per Redis pod)
- **Purpose**: Prometheus metrics
- **Image**: `oliver006/redis_exporter:v1.55.0-alpine`
- **Port**: 9121
- **Memory**: 64Mi-128Mi
- **CPU**: 50m-200m

## Security - NO HARDCODED SECRETS

### External Secrets Integration

All sensitive values are pulled from Azure Key Vault using External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: redis-ha-credentials
  namespace: flux-system
spec:
  secretStoreRef:
    name: azure-secret-store
    kind: ClusterSecretStore
  target:
    name: redis-ha-credentials
  data:
    - secretKey: redisPassword
      remoteRef:
        key: redis-password  # From Azure Key Vault
```

### Required Secrets in Azure Key Vault

Add the following secret to Azure Key Vault:

```bash
# Add Redis password to Key Vault
az keyvault secret set \
  --vault-name <your-keyvault-name> \
  --name redis-password \
  --value "$(openssl rand -base64 32)"
```

### Security Features

✅ **Password from Key Vault**: No hardcoded credentials
✅ **Non-root user**: Runs as UID 1000
✅ **Dropped capabilities**: All capabilities dropped
✅ **Seccomp profile**: RuntimeDefault
✅ **Network isolation**: ClusterIP services only
✅ **TLS ready**: Can be enabled in configuration

## High Availability Features

✅ **Automatic Failover**
- Sentinel detects master failure within 5 seconds
- Quorum of 2 Sentinels required for failover
- Automatic promotion of replica to master
- HAProxy automatically routes to new master

✅ **Data Persistence**
- AOF (Append-Only File) with fsync every second
- RDB snapshots (900s/1key, 300s/10keys, 60s/10000keys)
- Persistent volumes (10Gi per instance)
- Data survives pod restarts

✅ **Replication**
- Asynchronous replication from master to replicas
- Automatic resynchronization after network issues
- Replicas can serve read-only queries

✅ **Pod Anti-Affinity**
- Hard anti-affinity ensures pods on different nodes
- Prevents single node failure from affecting multiple pods
- Supports multi-AZ deployments

✅ **Load Balancing**
- HAProxy distributes connections
- Health checks detect failures
- Connection pooling reduces overhead

✅ **Resource Protection**
- Pod Disruption Budget (minimum 2 available)
- Liveness and readiness probes
- Resource limits prevent overconsumption

✅ **System Tuning**
- Init container sets kernel parameters
- `net.core.somaxconn=10000`
- Disables transparent huge pages

## Connection

### From Applications

**Primary Service**: `redis-ha-haproxy.redis.svc.cluster.local:6379`

This is the recommended connection point - HAProxy will handle routing to the current master.

```yaml
env:
  - name: REDIS_HOST
    value: "redis-ha-haproxy.redis.svc.cluster.local"
  - name: REDIS_PORT
    value: "6379"
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-ha-credentials
        key: redisPassword
```

### Alternative Connection (Direct to Master)

For clients that support Sentinel:

```yaml
env:
  - name: REDIS_SENTINEL_HOST
    value: "redis-ha.redis.svc.cluster.local"
  - name: REDIS_SENTINEL_PORT
    value: "26379"
  - name: REDIS_MASTER_NAME
    value: "mymaster"
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-ha-credentials
        key: redisPassword
```

## Verification

### Check All Pods
```bash
# Check all Redis HA components
kubectl get pods -n redis

# Expected output:
# - redis-ha-server-0, redis-ha-server-1, redis-ha-server-2
# - redis-ha-haproxy-<hash>-xxx (3 pods)
```

### Check Services
```bash
# List services
kubectl get svc -n redis

# Expected services:
# - redis-ha (Redis master)
# - redis-ha-haproxy (Load balancer - USE THIS)
# - redis-ha-announce-0, redis-ha-announce-1, redis-ha-announce-2
```

### Query Sentinel
```bash
# Get current master
kubectl exec -n redis redis-ha-server-0 -c sentinel -- \
  redis-cli -p 26379 sentinel get-master-addr-by-name mymaster

# Get Sentinel info
kubectl exec -n redis redis-ha-server-0 -c sentinel -- \
  redis-cli -p 26379 sentinel masters
```

### Test Redis Connection
```bash
# Get password from External Secret
REDIS_PASSWORD=$(kubectl get secret redis-ha-credentials -n flux-system \
  -o jsonpath='{.data.redisPassword}' | base64 -d)

# Connect via HAProxy
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h redis-ha-haproxy.redis.svc.cluster.local -a "$REDIS_PASSWORD" ping

# Should return: PONG
```

### Test Failover
```bash
# Simulate master failure by deleting current master pod
# First, find which pod is master
kubectl exec -n redis redis-ha-server-0 -c redis -- \
  redis-cli -a "$REDIS_PASSWORD" info replication | grep role

# Delete the master pod
kubectl delete pod redis-ha-server-<master-number> -n redis

# Watch Sentinel perform failover (10-15 seconds)
kubectl logs -n redis redis-ha-server-0 -c sentinel -f

# Verify new master
kubectl exec -n redis redis-ha-server-0 -c sentinel -- \
  redis-cli -p 26379 sentinel get-master-addr-by-name mymaster
```

## Monitoring

### Prometheus Metrics

Redis Exporter exposes metrics on port 9121:

```bash
# Port forward to access metrics
kubectl port-forward -n redis redis-ha-server-0 9121:9121

# Access metrics
curl http://localhost:9121/metrics
```

### Key Metrics to Monitor

- `redis_connected_clients`: Number of connected clients
- `redis_used_memory_bytes`: Memory usage
- `redis_instantaneous_ops_per_sec`: Operations per second
- `redis_connected_slaves`: Number of replicas
- `redis_master_last_io_seconds_ago`: Replication lag

### Enable ServiceMonitor (Optional)

If you have Prometheus Operator, enable ServiceMonitor in `values.yaml`:

```yaml
exporter:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
```

## Configuration

### Redis Settings
- **Memory limit**: 1GB with LRU eviction policy
- **Persistence**: AOF (every second) + RDB snapshots
- **Replication**: Diskless sync enabled
- **Slow log**: Queries > 10ms logged
- **Latency monitoring**: 100μs threshold

### Sentinel Settings
- **Monitor name**: mymaster
- **Quorum**: 2 (minimum Sentinels to agree)
- **Down after**: 5000ms
- **Failover timeout**: 10000ms
- **Parallel syncs**: 1

### HAProxy Settings
- **Check interval**: 2 seconds
- **Check fall**: 3 (failures to mark down)
- **Check rise**: 2 (successes to mark up)
- **Load balancing**: Round-robin to master only

## Scaling

### Scale Redis Replicas
```bash
# Increase Redis replicas
kubectl scale statefulset redis-ha-server -n redis --replicas=5

# Sentinel will automatically discover and monitor new replicas
```

### Scale HAProxy
```bash
# Increase HAProxy replicas for more connection capacity
kubectl scale deployment redis-ha-haproxy -n redis --replicas=5
```

## Backup and Recovery

### Manual Backup
```bash
# Trigger RDB save on master
REDIS_PASSWORD=$(kubectl get secret redis-ha-credentials -n flux-system \
  -o jsonpath='{.data.redisPassword}' | base64 -d)

# Find master pod
MASTER_POD=$(kubectl exec -n redis redis-ha-server-0 -c sentinel -- \
  redis-cli -p 26379 sentinel get-master-addr-by-name mymaster | head -1)

kubectl exec -n redis $MASTER_POD -c redis -- \
  redis-cli -a "$REDIS_PASSWORD" BGSAVE

# Copy dump from pod
kubectl cp redis/$MASTER_POD:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb -c redis
```

### Restore from Backup
```bash
# Copy dump to all pods
for i in 0 1 2; do
  kubectl cp ./redis-backup.rdb redis/redis-ha-server-$i:/data/dump.rdb -c redis
done

# Restart StatefulSet
kubectl rollout restart statefulset redis-ha-server -n redis
```

## Troubleshooting

### Check External Secret Status
```bash
# Check if secret is synced from Key Vault
kubectl get externalsecret redis-ha-credentials -n flux-system
kubectl describe externalsecret redis-ha-credentials -n flux-system

# Check created secret
kubectl get secret redis-ha-credentials -n flux-system
```

### Master Not Found
```bash
# Check Sentinel status
kubectl exec -n redis redis-ha-server-0 -c sentinel -- \
  redis-cli -p 26379 sentinel ckquorum mymaster

# Reset Sentinel if needed
kubectl exec -n redis redis-ha-server-0 -c sentinel -- \
  redis-cli -p 26379 sentinel reset mymaster
```

### Replication Issues
```bash
# Check replication on all pods
for i in 0 1 2; do
  echo "=== Pod $i ==="
  kubectl exec -n redis redis-ha-server-$i -c redis -- \
    redis-cli -a "$REDIS_PASSWORD" info replication
done
```

### HAProxy Not Routing
```bash
# Check HAProxy stats
kubectl exec -n redis <haproxy-pod> -- cat /usr/local/etc/haproxy/haproxy.cfg

# Check HAProxy logs
kubectl logs -n redis <haproxy-pod> -f
```

### Password Not Working
```bash
# Verify secret exists
kubectl get secret redis-ha-credentials -n flux-system

# Check External Secret status
kubectl describe externalsecret redis-ha-credentials -n flux-system

# Verify Azure Key Vault secret
az keyvault secret show --vault-name <vault> --name redis-password
```

## Performance Tuning

### Increase Memory
Edit `values.yaml`:
```yaml
redis:
  resources:
    limits:
      memory: 2Gi
  config:
    maxmemory: "2gb"
```

### Adjust Persistence
For higher write performance:
```yaml
redis:
  config:
    appendfsync: "no"  # Or "everysec" for balance
```

### Connection Pooling
Use connection pooling in your application:
- Python: `redis-py` with `ConnectionPool`
- Node.js: `ioredis` with connection pooling
- Java: `Jedis` or `Lettuce` with pooling

## Resource Requirements

### Total Cluster Resources
- **Redis**: 3 pods × 1Gi = 3Gi memory, 3 cores
- **Sentinel**: 3 × 256Mi = 768Mi memory, 1.5 cores
- **HAProxy**: 3 × 256Mi = 768Mi memory, 1.5 cores
- **Exporter**: 3 × 128Mi = 384Mi memory, 0.6 cores
- **Storage**: 30Gi total

**Total**: ~5Gi memory, ~6.6 cores, 30Gi storage

## Documentation

- Chart GitHub: https://github.com/DandyDeveloper/charts/tree/master/charts/redis-ha
- Redis Sentinel: https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/
- External Secrets: https://external-secrets.io/
- Azure Key Vault: https://docs.microsoft.com/en-us/azure/key-vault/

## Notes

✅ **NO HARDCODED SECRETS**: All passwords from Azure Key Vault
✅ **Production Grade**: HA, persistence, monitoring, tuning
✅ **Sentinel**: Automatic failover with quorum
✅ **HAProxy**: Load balancing and connection pooling
✅ **Anti-Affinity**: Pods on different nodes
✅ **PDB**: Minimum availability maintained
✅ **Monitoring**: Prometheus metrics via exporter
✅ **Security**: Non-root, dropped capabilities, seccomp

This is a fully production-ready Redis HA deployment! 🎉
