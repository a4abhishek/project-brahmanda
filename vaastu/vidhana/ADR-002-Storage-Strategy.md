# **ADR-002: Storage Strategy**

Date: 2025-12-31
Status: Accepted

## **Context**

The homelab currently consists of a single compute node (NUC 14 Pro Plus) with plans to expand to a multi-node cluster. We need a Kubernetes-native storage solution that provides persistent block storage for databases and services. Disaster recovery must be budget-conscious, leveraging cost-effective cloud storage without breaking the budget.

For a detailed discussion and rationale, please see [Manthana/002-Storage-Strategy.md](../Manthana/002-Storage-Strategy.md).

## **Decision**

We will use **Longhorn** (CNCF Sandbox Project) as the storage engine for the Kubernetes cluster, with disaster recovery backups to **Cloudflare R2** for cost efficiency and unlimited egress. We explicitly reject **Rook-Ceph** for this specific phase.

## **Consequences**

- **Positive:** Simplicity, Scale-out, Cost-effective.
- **Negative:** Performance, Network Traffic.
