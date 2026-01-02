# **ADR-001: Hybrid Cloud Homelab Architecture**

Date: 2025-12-31
Status: Accepted

## **Context**

We need a scalable, secure, and professional homelab environment for experimentation (Kubernetes, AI/LLMs, Go services). The system must be accessible from the public internet but isolated from the physical home LAN to prevent lateral movement in case of a breach.

For a detailed discussion and rationale, please see [manthana/RFC-001-Homelab-Architecture.md](../manthana/RFC-001-Homelab-Architecture.md).

## **Decision**

We will adopt a **Hybrid Cloud Overlay** architecture consisting of three layers:

### **1. Edge Layer: Project Kshitiz (Lighthouse)**

- **Service:** AWS Lightsail with IPv4 ($5/mo) in Singapore Region.
- **Instance:** Lightsail with 1TB bandwidth.
- **Operating System:** Ubuntu 22.04 LTS.
- **Role:** Static public entry point and Nebula Lighthouse.
- **Firewall Rules:**
  - UDP/4242 (Nebula)
  - TCP/22 (SSH - restricted to admin IP)
  - All other ports closed by default

### **2. Transport Layer: Nebula Mesh**

- **Technology:** Nebula Overlay Network (Slack open-source).
- **Architecture:** Certificate-based authentication, UDP hole-punching.
- **Scope:** Nebula is used **exclusively for external access** (North-South traffic). Kubernetes node-to-node communication (East-West) uses the local LAN.
- **Groups:**
  - `lighthouse`: Kshitiz gateway (public entry point)
  - `public-ingress`: Reverse proxy VMs (terminates public traffic)
- **Firewall Policy:** Zero-trust, explicit allow rules only.

**Note on Cluster Communication:**

- **Current (Single Node):** All traffic is local.
- **Near Future (Multi-Node Local):** Nodes communicate over VLAN 30 (local LAN) for Etcd, Longhorn, and Pod networking.
- **Far Future (Multi-Regional):** If regional expansion is needed, a dedicated WAN solution will be evaluated separately.

### **3. Compute Layer: Project Vyom (On-Prem)**

- **Hardware:** ASUS NUC 14 Pro Plus
  - CPU: Intel Ultra 5 125H
  - RAM: 48GB DDR5 5600MHz (expandable to 96GB)
  - Storage: 2TB NVMe Gen4 (WD SN850X)
- **Hypervisor:** Proxmox VE 8.x
- **Network:** Static IP (192.168.68.200/24)
- **Orchestration:** K3s (Lightweight Kubernetes)
  - HA Configuration: 1 control-plane, 2+ workers (future)
  - Networking: Flannel (default CNI)
  - Storage: Longhorn (distributed block storage)

## **Implementation Steps**

### **Phase 1: Edge Provisioning (Terraform)**

```hcl
# samsara/terraform/kshitiz/main.tf
resource "aws_lightsail_instance" "kshitiz" {
  name              = "kshitiz-lighthouse"
  availability_zone = "ap-southeast-1a"
  blueprint_id      = "ubuntu_22_04"
  bundle_id         = "nano_3_0"
}

resource "aws_lightsail_static_ip" "kshitiz" {
  name = "kshitiz-static-ip"
}
```

### **Phase 2: Mesh Setup (Ansible)**

- Generate Nebula CA certificate locally.
- Issue certificates for each node (Lighthouse, Ingress, Workers).
- Deploy `nebula` binary and systemd service via Ansible role.

### **Phase 3: Compute Bootstrap (Terraform + Cloud-Init)**

- Use Proxmox provider to clone Ubuntu Cloud-Init template.
- Inject SSH keys and static IP via Cloud-Init.
- Run Ansible playbook to install K3s.

### **Phase 4: GitOps (ArgoCD)**

- Deploy ArgoCD into K3s cluster.
- Point to `sankalpa/` directory in Git.
- Auto-sync application deployments.

## **Consequences**

- **Positive:** "Zero Trust" networking by default. No open ports on the home ISP router. High portability.
- **Negative:** Added latency. Requires managing Nebula certificates (PKI).
