# **RFC 001: Hybrid Cloud Homelab Architecture (Project Brahmanda)**

I need a scalable, secure, and professional homelab environment for my experimentation (Kubernetes, AI/LLMs, Go services). The system must be accessible from the public internet but isolated from the physical home LAN to prevent lateral movement in case of a breach.

## **Naming Convention**

To maintain a cohesive engineering dialect, the following internal codenames are adopted:

- **Project Vyom (Cluster):** The Compute Layer (NUC). Represents the isolated universe where apps and data live.
- **Project Kshitiz (Edge):** The Lighthouse Gateway. Represents the "Horizon" where the public cloud meets our private ground.
- **Project Samsara (Pipelines):** The Automation Strategy. Represents the immutable cycle of infrastructure creation and destruction.

## **Decision**

We will adopt a **Hybrid Cloud Overlay** architecture consisting of three layers:

1. **Edge Layer: Project Kshitiz (Lighthouse)**
   - **Service:** AWS Lightsail with IPv4 ($5/mo) in Singapore Region for 1TB bandwidth. Mumbai Region only offers 500GB bandwidth at same price.
   - **Role:** Acts as the stable public entry point (Static IP) and Nebula Lighthouse.
   - **Justification:** Cheaper and more predictable than EC2. Decouples our home IP from the public DNS.
2. **Transport Layer (Mesh)**
   - **Technology:** Nebula Overlay Network.
   - **Role:** Provides an encrypted, mutual-TLS mesh between Kshitiz and Vyom.
   - **Justification:** Natively handles NAT traversal (UDP hole punching), removing the need for dangerous port forwarding on the home router.
3. **Compute Layer: Project Vyom (On-Prem)**
   - **Hardware:** ASUS NUC 14 Pro Plus (48GB RAM, 2TB SSD).
   - **Hypervisor:** Proxmox VE.
   - **Orchestration:** K3s (Kubernetes) running inside VMs.
   - **Justification:** Proxmox allows mixed workloads (VMs for K8s, LXC for lightweight tools). K3s is production-grade but resource-efficient.

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

- **Goal:** Install mesh binaries and distribute certificates.
- **Tool:** **Ansible**.
- **Implementation:**
  - Role: utkuozdemir.nebula (Community standard).
  - **Method:** Ansible identifies the host group (lighthouse vs home-nodes), pushes the specific crt and key files from a secure local vault (e.g., Ansible Vault), and enables the systemd service.

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
