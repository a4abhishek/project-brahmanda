# **ADR-002: Storage Strategy**

Date: 2025-12-31
Status: Accepted

## **Context**

The homelab currently consists of a single compute node (NUC 14 Pro Plus) with plans to expand to a multi-node cluster. We need a Kubernetes-native storage solution that provides persistent block storage for databases and services. Disaster recovery must be budget-conscious, leveraging cost-effective cloud storage without breaking the budget.

For a detailed discussion and rationale, please see [manthana/RFC-002-Storage-Strategy.md](../manthana/RFC-002-Storage-Strategy.md).

## **Decision**

We will use **Longhorn** (CNCF Sandbox Project) as the storage engine for the Kubernetes cluster, with disaster recovery backups to **Cloudflare R2** for cost efficiency and unlimited egress. We explicitly reject **Rook-Ceph** for this specific phase.

## **Implementation**

### **1. Installation**

**Method:** Helm Chart deployment via ArgoCD.

```yaml
# sankalpa/core/longhorn.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: longhorn
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.longhorn.io
    chart: longhorn
    targetRevision: 1.6.0
    helm:
      values: |
        defaultSettings:
          defaultReplicaCount: 1  # Single node initially
          storageMinimalAvailablePercentage: 10
          backupTarget: s3://brahmanda-sanchaya-backups@us-east-1/
          backupTargetCredentialSecret: longhorn-r2-secret
  destination:
    server: https://kubernetes.default.svc
    namespace: longhorn-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### **2. R2 Backup Configuration**

**Create Kubernetes Secret:**

```bash
kubectl create secret generic longhorn-r2-secret \
  -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID=<r2-access-key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<r2-secret-key> \
  --from-literal=AWS_ENDPOINTS=https://<account-id>.r2.cloudflarestorage.com
```

**Backup Schedule:**
- **Recurring Job:** Every 6 hours
- **Retention:** Keep last 7 snapshots
- **Compression:** Enabled (reduces R2 storage costs)

### **3. Storage Class**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "30"
  fromBackup: ""
allowVolumeExpansion: true
reclaimPolicy: Retain
```

### **4. Scaling Strategy**

**When adding second node:**
```bash
kubectl patch storageclass longhorn -p '{"parameters": {"numberOfReplicas": "2"}}'
```

This automatically replicates new volumes across both nodes.

## **Consequences**

- **Positive:** Simplicity, Scale-out, Cost-effective.
- **Negative:** Performance, Network Traffic.
