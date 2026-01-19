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

#### **Virtual Machine Sizing Plan**

To run a robust K3s cluster on the Proxmox hypervisor, the following initial VM resource allocation will be implemented. This plan is based on the currently installed **48GB RAM**.

| Node Role         | # of VMs | vCPUs | RAM   | Storage | Rationale                                                                                                                                                                             |
| :---------------- | :------- | :---- | :---- | :------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Control-Plane** | 1        | 4     | 8 GB  | 64 GB   | The "brain" of the cluster. Needs sufficient CPU/RAM for the Kubernetes API server, etcd, and controller manager. 64GB storage is ample for etcd data and cached container images.           |
| **Worker Node**   | 2        | 4     | 16 GB | 128 GB  | The "muscle" where applications run. More RAM is allocated for application workloads. More storage is provided for container images and persistent data volumes managed by Longhorn.      |
| **Total**         | **3 VMs**  | **12**  | **40 GB** | **320 GB**| This configuration uses a significant portion of the available 48GB system RAM, leaving a modest 8GB buffer for the Proxmox host OS and other lightweight services. |

## Vyom Provisioning and Image Management

The strategy for provisioning and maintaining VMs for the `Vyom` compute layer is implemented in two phases, as detailed in `RFC-009` and `RFC-010`.

### Phase 1: Template Cloning (Implemented)

- **Decision:** All `Vyom` virtual machines will be provisioned by cloning a master "golden image" template in Proxmox. This is significantly faster and more consistent than repeated ISO-based installations. This decision is based on **[RFC-009: Vyom (Compute Layer) Provisioning Strategy](../manthana/RFC-009-Vyom-Provisioning-Strategy.md)**.
- **Implementation Details:** The `prakriti-template` is created via a secure, manual, one-time process that ensures a master key is baked in for emergency access.
    1. **Generate Master Key:** A dedicated SSH key pair, the `Prakriti Master Key`, is generated locally. The private key is stored securely in 1Password, and the local copies are destroyed.
    2. **Prepare Host:** The public key is retrieved from 1Password and uploaded to the Proxmox host's `/tmp` directory. The Ubuntu 24.04 cloud image is also uploaded.
    3. **Create & Configure VM:** A new VM is created and configured using a series of `qm` commands. Crucially, a temporary static IP and the path to the uploaded public key are injected for the first boot:

        ```bash
        # Set temporary IP and SSH key for agent installation
        qm set 9000 --ipconfig0 ip=192.168.68.201/20,gw=192.168.68.1
        qm set 9000 --sshkeys /tmp/prakriti-master-key.pub
        ```

    4. **Install Agent:** The temporary VM is started. The operator SSHes into the VM using the temporary IP and the `Prakriti Master Key` (retrieved from 1Password) to install the `qemu-guest-agent` package. The VM is then shut down.
    5. **Finalize & Clean Up:** The temporary public key is deleted from the Proxmox host. The VM's network configuration is reset to DHCP (`qm set 9000 --ipconfig0 ip=dhcp`) so that cloned VMs can be configured by Terraform. Finally, the VM is converted to a read-only template (`qm template 9000`).
- **Status:** This manual, one-time process is complete. The `prakriti-template` exists in Proxmox and is ready for use by Terraform. The full, step-by-step operator guide for this process is in `vaastu/001-Sarga.md`.

### Phase 2: Automated Image Baking & Patching (Future Work)

- **Decision:** To fully embrace the "Infrastructure as Code" philosophy and ensure templates do not become stale, the manual creation process will be replaced by an automated pipeline using HashiCorp Packer and Ansible. This decision is based on **[RFC-010: Golden Image & Patch Management Strategy](../manthana/RFC-010-Golden-Image-And-Patch-Management-Strategy.md)**.
- **Implementation (Planned):**
  - A Packer template will be created in `samsara/packer/`.
  - This Packer build will automate all the steps from Phase 1: downloading the ISO, installing the OS, and running an Ansible playbook to install the `qemu-guest-agent` and other necessary tools.
  - A separate, scheduled Ansible playbook (`maintenance-upgrade.yml`) will be created to apply ongoing security patches to live, running VMs.
- **Status:** This is the next planned iteration for the `Vyom` layer's lifecycle management.

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

- Use the Proxmox Terraform provider to clone the `prakriti-template` created in the provisioning phase.
- Inject node-specific configurations (hostname, static IP addresses) for each K3s node via Cloud-Init metadata.
- Run an Ansible playbook to install K3s onto the provisioned VMs. The implementation details for this are defined in the relevant ADRs for software deployment.

### **Phase 4: GitOps (ArgoCD)**

- Deploy ArgoCD into K3s cluster.
- Point to `sankalpa/` directory in Git.
- Auto-sync application deployments.

## **Consequences**

- **Positive:** "Zero Trust" networking by default. No open ports on the home ISP router. High portability.
- **Negative:** Added latency. Requires managing Nebula certificates (PKI).
