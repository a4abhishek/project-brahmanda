# **RFC-012: Terraform State & Distributed Locking Strategy**

- **Status:** Accepted
- **Date:** 2026-01-23
- **Author:** Brahmanda Architect
- **Related ADR:** [ADR-006: Brahmaloka Orchestration Plane](../vidhana/ADR-006-Brahmaloka-Orchestration-Plane.md)

## **1. The Context (Prastavana)**

As we move from local development to the `Samsara` automation cycle (CI/CD), managing the Terraform State (`terraform.tfstate`) locally is no longer viable. We need a remote backend to share state between the developer's machine and the CI runners.

Furthermore, we need a locking mechanism to prevent concurrent execution of infrastructure changes (Race Conditions), which could corrupt the state or leave infrastructure in an inconsistent state.

Crucially, **Project Brahmanda** is a self-funded Homelab without corporate backing. Financial frugality (*Aparigraha*) is a primary constraint. We aim to minimize recurring costs and vendor lock-in where possible.

## **2. Scope Definition (Seema)**

### **Current Scope**

- Storing Terraform state securely and remotely.
- Implementing a distributed locking mechanism ("The Lease") to prevent concurrent runs.
- Defining the "Atomic Unit" of execution (Infrastructure + Configuration).

### **Out of Scope**

- Secrets management (Handled by RFC-007 / 1Password).
- Multi-cloud federation logic.

## **3. The Proposal (Prastava)**

We will adopt a **Hybrid State & Locking** strategy that optimizes for cost and simplicity, accepting specific trade-offs.

### **A. State Storage: Cloudflare R2**

We will use **Cloudflare R2** as the S3-compatible backend for Terraform state files.

- **Cost:** $0 (Free Tier: 10GB storage, 10M reads/month).
- **Egress:** $0 (No egress fees).
- **Implementation:** `backend "s3"` block in Terraform, pointing to the R2 endpoint.

### **B. State Locking: "The Makefile Lease" (Upstash Redis)**

We will implement a custom distributed lock using **Upstash Redis** (via HTTP API) integrated directly into the `Makefile`.

- **Mechanism:** Before running *any* automation target (`kshitiz`, `vyom`), the Makefile attempts to acquire a lock in Redis (`SET NX PX`).
- **Scope:** The lock covers the **Entire Atomic Unit** of work: Terraform Provisioning **AND** Ansible Configuration.
- **Implementation:** `curl` calls to Upstash REST API.

### **C. CI/CD Concurrency: GitHub Actions**

We will use **GitHub Actions Concurrency Groups** as the primary "Process Lock" for automated runs.

- **Mechanism:** `concurrency: production` in workflow YAML.
- **Effect:** Queues pending jobs, ensuring serialization at the platform level.

## **4. The Alternatives (Vikalpa)**

### **Option A: AWS S3 + DynamoDB (The Industry Standard)**

- **Description:** Store state in S3, lock with DynamoDB table.
- **Pros:** Natively supported by Terraform. Robust. "Just Works".
- **Cons:** Requires AWS account (we have one). Free tier expires after 12 months (S3 standard is cheap but not free).
- **Verdict:** **Rejected.** While technically superior, we prefer R2 for its permanent free tier and zero-egress model, aligning with the project's frugality goals.

### **Option B: Cloudflare R2 + AWS DynamoDB (The Hybrid)**

- **Description:** R2 for storage, DynamoDB for locking.
- **Pros:** Free storage, robust locking.
- **Cons:** **Credential Hell.** Terraform's S3 backend does not easily support separate credentials for Storage and Locking within the same block without complex profile management.
- **Verdict:** **Rejected.** The complexity of managing dual credentials in CI/CD outweighs the benefit.

### **Option C: GitLab Managed Backend (The SaaS)**

- **Description:** Use GitLab's free Terraform HTTP backend.

- **Pros:** Free state + Native locking.
- **Cons:** We are building a self-hosted platform on GitHub. Adding GitLab just for state splits the ecosystem ("Split-Brain").
- **Verdict:** **Rejected.**

## **5. The Dangers & Trade-offs (Sankata)**

We explicitly acknowledge the risks of the "Makefile Lease" approach:

1. **Non-Native Locking:** Terraform itself is unaware of the lock. If a user bypasses the Makefile and runs `terraform apply` manually, they can corrupt the state.
    - *Mitigation:* Humans are forbidden from running manual Terraform in production. All changes must go through the Makefile or CI/CD.
2. **Crash Resilience:** If the Makefile process crashes hard (e.g., OOM kill) *after* acquiring the lock but *before* releasing it, the lock will persist until its TTL (Time-To-Live) expires (e.g., 10 minutes).
    - *Mitigation:* Set a reasonable TTL. Manual intervention (delete key) required in worst-case.
3. **Race Conditions:** There is a tiny theoretical window between checking the lock and Terraform starting, but Redis `SET NX` is atomic, minimizing this.

**Why we accept this:** The cost savings (free Redis vs paid DynamoDB/S3) and the ability to lock the **entire pipeline** (including Ansible) make this superior for our specific constraints.

## **6. The Conclusion (Nishkarsha)**

We choose **Cloudflare R2** for state storage and **Upstash Redis** for distributed locking via the Makefile. This "Asanga" approach creates a zero-cost, highly available, and atomic locking mechanism that protects the entire deployment lifecycle, not just the Terraform phase.
