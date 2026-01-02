# **ADR 004: Security Hardening Strategy**

Date: 2026-01-03<br>
Status: Accepted

## **Context**

Project Brahmanda exposes services to the internet. We need to secure the infrastructure against external attacks and limit the blast radius if a component is compromised.

For a detailed analysis of options, see [manthana/RFC-004-Security-Hardening.md](../manthana/RFC-004-Security-Hardening.md).

## **Decision**

We will implement a **Defense-in-Depth** strategy consisting of:

1.  **Network Segmentation (VLANs):**

    **VLAN Configuration:**
    - **VLAN 10 (Home) - 192.168.10.0/24:** Trusted devices (Phones, Laptops, Personal computers).
    - **VLAN 20 (Mgmt) - 192.168.20.0/24:** Admin access (Proxmox UI at .200, SSH, IPMI).
    - **VLAN 30 (DMZ) - 192.168.30.0/24:** Exposed workloads (K8s VMs, Reverse Proxy).

    **Firewall Rules (Router/Firewall Level):**
    ```
    # Inter-VLAN Policy
    Home (VLAN 10) -> Mgmt (VLAN 20): ALLOW (admin needs to manage Proxmox)
    Home (VLAN 10) -> DMZ (VLAN 30): DENY (no direct access to cluster)
    Mgmt (VLAN 20) -> DMZ (VLAN 30): ALLOW (management needs to access K8s nodes)
    DMZ (VLAN 30) -> Home (VLAN 10): DENY (compromised workload cannot pivot to home)
    DMZ (VLAN 30) -> Mgmt (VLAN 20): DENY (compromised workload cannot access Proxmox)
    DMZ (VLAN 30) -> Internet: ALLOW (K8s needs to pull images)
    ```

    **Implementation:**
    - Configure VLAN tagging on managed switch.
    - Set Proxmox bridge (vmbr0) to trunk mode.
    - Assign VM network interfaces to specific VLANs via Proxmox UI or Terraform.

    **Example (Terraform - Proxmox VM):**
    ```hcl
    resource "proxmox_vm_qemu" "k8s_worker" {
      name = "k8s-worker-01"
      network {
        bridge = "vmbr0"
        tag    = 30  # DMZ VLAN
      }
    }
    ```

2.  **Nebula Mesh Security & Traffic Flow:**

    - **Split-Horizon Strategy:**
        - **Intra-Cluster (East-West):** All node-to-node traffic (Etcd, Longhorn, Pods) MUST use the **Local LAN (VLAN 30)**. We avoid Nebula for internal traffic to prevent encryption overhead and latency.
        - **Ingress (North-South):** Nebula is used strictly for secure external access (Lighthouse -> Cluster).
    - **Firewall Rules:**
        - `group:lighthouse`: UDP/4242 only.
        - `group:public-ingress`: Only group allowed to accept inbound HTTP/80 and HTTPS/443 from Lighthouse.

3.  **Host Hardening (Ansible):**

    - **SSH:** Disable password authentication (`PasswordAuthentication no`). Use Ed25519 keys.
    - **Fail2Ban:** Install on Kshitiz (Gateway) to ban IPs after 3 failed attempts.
    - **Unprivileged Containers:** LXC containers must map root to a non-root user.

4.  **Emergency Kill Switch (Layered Defense):**
    - **Level 1 (Software):** A local script on the host to stop networking, which is also triggerred by a **GitHub Action** that destroys the Lighthouse (Kshitiz) to instantly sever public internet access.
    - **Level 2 (Remote Hardware):** A **16A Smart Plug** connects the NUC to the wall. Allows for a remote "Hard Kill" if the OS is compromised or frozen.
    - **Level 3 (Physical):** The **Physical Wall Switch** serves as the ultimate, unhackable fail-safe requiring physical presence.

## **Consequences**

- **Positive:**
  - Compromise of a K8s node does not grant access to the home network.
  - Identity-based networking (Nebula) prevents unauthorized devices from joining the mesh even if they have the IP.
- **Negative:**
  - Increased network complexity (VLAN management).
  - Requires a router/switch capable of VLAN tagging.
