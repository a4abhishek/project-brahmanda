# **RFC 001: Hybrid Cloud Homelab Architecture (Project Brahmanda)**

I need a scalable, secure, and professional homelab environment for my experimentation (Kubernetes, AI/LLMs, Go services). The system must be accessible from the public internet but isolated from the physical home LAN to prevent lateral movement in case of a breach.

## **Naming Convention**

To maintain a cohesive engineering dialect, the following internal codenames are adopted:

- **Project Vyom (Cluster):** The Compute Layer (NUC). Represents the isolated universe where apps and data live.
- **Project Kshitiz (Edge):** The Lighthouse Gateway. Represents the "Horizon" where the public cloud meets our private ground.
- **Project Samsara (Pipelines):** The Automation Strategy. Represents the immutable cycle of infrastructure creation and destruction.

## **Scope Definition**

### **Current Scope (Phase 1)**

- Single-node Proxmox host (ASUS NUC 14 Pro Plus)
- AWS Lightsail as public gateway (Nebula Lighthouse)
- Nebula mesh for **North-South traffic only** (external access)
- Local LAN (VLAN 30) for all Kubernetes internal communication (Etcd, Longhorn, Pod networking)
- K3s single control-plane deployment
- GitOps via ArgoCD for application deployment

### **Future Scope (Phase 2+)**

- **Near-term:** Multi-node local expansion
  - Additional NUC nodes or Jetson for GPU workloads
  - Longhorn replica count increase to 2-3 for redundancy
  - K3s HA with multiple control-plane nodes
  - All nodes remain on the same physical LAN (VLAN 30)
- **Long-term:** Enhanced observability and automation
  - Centralized logging (Loki)
  - Advanced monitoring (Prometheus/Grafana federation)
  - Automated scaling policies

### **Out of Scope**

- **Multi-regional WAN architecture:** Connecting clusters across different geographical locations requires a separate RFC to evaluate WAN mesh solutions, latency considerations, and data replication strategies.
- **Multi-datacenter storage:** Distributed storage across regions (e.g., CockroachDB geo-replication) is not addressed in this RFC.
- **Edge Computing:** Running workloads outside the home network (IoT devices, remote edge nodes) is not covered.

## **Decision**

We will adopt a **Hybrid Cloud Overlay** architecture consisting of three layers:

1. **Edge Layer: Project Kshitiz (Lighthouse)**
   - **Service:** AWS Lightsail with IPv4 ($5/mo) in Singapore Region for 1TB bandwidth. Mumbai Region only offers 500GB bandwidth at same price.
   - **Role:** Acts as the stable public entry point (Static IP) and Nebula Lighthouse.
   - **Justification:** Cheaper and more predictable than EC2. Decouples our home IP from the public DNS.
2. **Transport Layer (Mesh)**
   - **Technology:** Nebula Overlay Network.
   - **Role:** Provides an encrypted, mutual-TLS mesh between Kshitiz (public gateway) and the ingress layer of Vyom.
   - **Justification:** Natively handles NAT traversal (UDP hole punching), removing the need for dangerous port forwarding on the home router.
   - **Scope:** Nebula is used **only for North-South traffic** (public internet to cluster ingress). Kubernetes internal communication (node-to-node, Etcd, Longhorn replication) occurs over the **local LAN (VLAN 30)** to avoid encryption overhead and latency.
   - **Scaling Strategy:**
     - **Current:** Single node, all traffic is local.
     - **Near Future:** Multiple nodes on the same physical LAN communicate directly over VLAN 30.
     - **Far Future:** Multi-regional expansion (if needed) will require a separate WAN architecture decision (not in scope for this RFC).
3. **Compute Layer: Project Vyom (On-Prem)**
   - **Hardware:** ASUS NUC 14 Pro Plus (48GB RAM, 2TB SSD).
   - **Hypervisor:** Proxmox VE.
   - **Orchestration:** K3s (Kubernetes) running inside VMs.
   - **Justification:** Proxmox allows mixed workloads (VMs for K8s, LXC for lightweight tools). K3s is production-grade but resource-efficient.

## 3. Vyom (Compute Layer) Resource Allocation

To run a robust and scalable K3s cluster on the Proxmox hypervisor, the following initial VM resource allocation is proposed. This plan is based on the currently installed **48GB RAM** on the ASUS NUC.

### Virtual Machine Sizing Plan

| Node Role         | # of VMs | vCPUs | RAM   | Storage | Rationale                                                                                                                                                                             |
| :---------------- | :------- | :---- | :---- | :------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Control-Plane** | 1        | 4     | 8 GB  | 64 GB   | The "brain" of the cluster. Needs sufficient CPU/RAM for the Kubernetes API server, etcd, and controller manager. 64GB storage is ample for etcd data and cached container images.           |
| **Worker Node**   | 2        | 4     | 16 GB | 128 GB  | The "muscle" where applications run. More RAM is allocated for application workloads. More storage is provided for container images and persistent data volumes managed by Longhorn.      |
| **Total**         | **3 VMs**  | **12**  | **40 GB** | **320 GB**| This configuration uses a significant portion of the available 48GB system RAM, leaving a modest 8GB buffer for the Proxmox host OS and other lightweight services. This is an efficient use of resources for a powerful baseline cluster. |

This 1-server, 2-worker topology provides a good balance of resource usage and high availability for deployed applications.

## **Consequences**

- **Positive:** "Zero Trust" networking by default. No open ports on the home ISP router. High portability (can move the NUC anywhere without breaking access).
- **Negative:** Added latency (extra hop via Lightsail). Requires managing Nebula certificates (PKI).

## **Compliance & Security**

- **Isolation:** The "Public" traffic never touches the physical Home LAN; it is encapsulated inside the Nebula tunnel and terminated at a specific Reverse Proxy VM in Vyom.

## **Automation Strategy: Project Samsara**

We will adhere to the "Infrastructure as Code" (IaC) principle. Manual console clicking is forbidden after the initial bootstrap.

### **1\. Bare Metal Automation (Proxmox Host)**

- **Goal:** Automated OS installation and host configuration.
- **Tool:** **Proxmox Auto-Install Assistant** (Official).
- **Implementation:**
  - Create an answer.toml file defining the disk layout (ZFS/LVM), network static IP, timezone, and root password.
  - Bake this into the official ISO using the proxmox-auto-install-assistant tool.
  - **Result:** Plug in USB, boot, walk away. The NUC installs itself and reboots into a ready state.
- **Post-Install Config:** **Ansible**.
  - Use Ansible to configure the "Day 1" items: Users, SSH keys, non-subscription repositories, and basic firewall rules.

### **2\. Edge Layer Automation (Kshitiz)**

- **Goal:** Provision the Lighthouse and firewall rules.
- **Tool:** **Terraform**.
- **Implementation:**
  - Provider: hashicorp/aws.
  - Resource: aws_lightsail_instance and aws_lightsail_static_ip.
  - **Network Config:** Define firewall rules (allow UDP/4242, allow SSH from admin IP only) directly in the Terraform resource block.

### **3\. Virtualization Automation (Vyom VMs)**

- **Goal:** Create and destroy Kubernetes nodes declaratively.
- **Tool:** **Terraform** \+ **Cloud-Init**.
- **Implementation:**
  - Provider: bpg/proxmox (Modern, feature-rich provider).
  - **Method:** Terraform clones a Cloud-Init template.
  - **Network Config:** Terraform injects the IP address, Gateway, and SSH keys via the ciuser, ipconfig0, and sshkeys Cloud-Init variables. No manual console login required.

### **4\. Transport Automation (Nebula)**

- **Goal:** Install mesh binaries and distribute certificates for external access.
- **Tool:** **Ansible**.
- **Implementation:**
  - Role: utkuozdemir.nebula (Community standard).
  - **Method:** Ansible identifies the host group (lighthouse vs ingress-nodes), pushes the specific crt and key files from a secure local vault (e.g., Ansible Vault), and enables the systemd service.
  - **Scope:** Only the Lighthouse (Kshitiz) and Ingress VMs (public-facing reverse proxies) require Nebula. Kubernetes worker nodes communicate over the local LAN and do NOT need Nebula certificates.

### **5\. Orchestration Automation (Kubernetes)**

- **Goal:** Bootstrap the cluster and join nodes.
- **Tool:** **Ansible** (via k3s-ansible).
- **Implementation:**
  - **Why Ansible?** Terraform is great for _creating_ the VMs, but Ansible is superior for _configuring_ the software inside them.
  - Use the official k3s-io/k3s-ansible playbook. It automates the master setup, token generation, and worker node joining.

### **6\. Service Deployment (GitOps)**

- **Goal:** Deploy apps (Ollama, Grafana, Custom Go Services).
- **Tool:** **ArgoCD** (running inside K8s).
- **Implementation:**
  - Once K3s is up, apply a single manifest to install ArgoCD.
  - Point ArgoCD to your GitHub repository.
  - All future service changes happen via git push.
