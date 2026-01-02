# **RFC 002: Storage Strategy (Longhorn vs. Ceph)**

The homelab currently consists of a single compute node (NUC 14 Pro Plus) with plans to expand to a multi-node cluster (adding Jetson/NUCs). We need a Kubernetes-native storage solution that provides persistent block storage for databases and services.

## **Decision**

We will use **Longhorn** (CNCF Sandbox Project) as the storage engine for the Kubernetes cluster. We explicitly reject **Rook-Ceph** for this specific phase.

## **Detailed Rationale**

### **1\. The "Quorum" Problem**

- **Ceph** requires a quorum of monitors (minimum 3 for production stability) to maintain consensus. Running Ceph on a single node ("MicroCeph") introduces significant risk of data unavailability during maintenance or partial failures.
- **Longhorn** is designed to function with a flexible replica count. It operates natively on a single node (Replica=1) without complex consensus overhead, making it ideal for the initial "Day 1" setup.

### **2\. Resource Overhead**

- **Ceph** OSDs and Monitors consume significant CPU and RAM, effectively "taxing" the NUC's resources that should be reserved for application workloads (Go services, LLMs).
- **Longhorn** is lightweight. It spawns controller pods only when volumes are active.

### **3\. Disaster Recovery (DR) Strategy**

- **Decision:** We will leverage Longhorn's native **R2 Backup** capability (S3-compatible).
- **Rationale - Budget-Optimized for Personal Projects:**

  - **Free tier:** 10GB/month storage included + unlimited free egress (no egress charges, unlike AWS S3)
  - **Pricing:** $0.015/GB for storage beyond free tier (vs AWS S3 Standard-IA at $0.0125/GB + significant egress costs)
  - **S3-compatible API:** Works seamlessly with Longhorn's existing backup mechanisms without code changes
  - **Cost-effective for homelab:** A single NUC with 2TB NVMe generating ~500GB snapshots/month stays within the free 10GB/month for compressed deduplicated backups, resulting in $0 ongoing storage costs
  - **Budget advantage:** For personal projects with limited budgets, R2's no-egress-charge model saves 30-50% compared to AWS S3 over time

- **Implementation:**
  - Scheduled snapshots (e.g., every 6 hours) will be deduplicated and pushed to Cloudflare R2 bucket (`brahmanda-longhorn-backups`)
  - This decouples data safety from the physical NUC. If the NVMe drive fails, data can be restored to a fresh cluster from R2
  - Configure Kubernetes Secret with R2 credentials (access-key-id, secret-access-key, endpoint URL)

## **Consequences**

- **Positive:**
  - **Simplicity:** Lower operational burden for a single SRE.
  - **Scale-out:** Adding a new node allows us to simply increase the NumberOfReplicas to 2 or 3 without re-architecting the storage layer.
  - **Cost:** No need to purchase 3 nodes immediately to get "High Availability" storage.
- **Negative:**
  - **Performance:** Longhorn (block storage over iSCSI/TCP) is generally slower than raw disk or optimized Ceph RBD, though sufficient for homelab databases.
  - **Network Traffic:** Replicas are synchronized over the network. As we scale to multiple nodes, 2.5GbE bandwidth usage will increase.

## **Implementation Plan**

1. **Install:** Deploy via Helm Chart (longhorn/longhorn).
2. **Config:** Set default replica-count to 1 (initially).
3. **Backup:** Configure Kubernetes Secret with AWS S3 credentials and set backup schedule.
