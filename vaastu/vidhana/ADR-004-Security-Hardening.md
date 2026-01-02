# **ADR 004: Security Hardening Strategy**

Date: 2026-01-03<br>
Status: Accepted

## **Context**

Project Brahmanda exposes services to the internet. We need to secure the infrastructure against external attacks and limit the blast radius if a component is compromised.

For a detailed analysis of options, see [Manthana/RFC-004-Security-Hardening.md](../Manthana/RFC-004-Security-Hardening.md).

## **Decision**

We will implement a **Defense-in-Depth** strategy consisting of:

1.  **Network Segmentation (VLANs):**

    - **VLAN 10 (Home):** Trusted devices (Phones, Laptops).
    - **VLAN 20 (Mgmt):** Admin access (Proxmox UI, SSH).
    - **VLAN 30 (DMZ):** Exposed workloads (K8s VMs).
    - **Rule:** DMZ cannot initiate connections to Home or Mgmt.

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
