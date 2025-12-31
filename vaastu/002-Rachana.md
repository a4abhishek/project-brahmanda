# ** Rachana (The Structure)**

This document details the architecture of **Project Brahmanda**, covering the infrastructure, automation, and security aspects.

## **Infrastructure as Code (IaC) Plan**

### **Tooling Choices**

*   **Provisioning:** Terraform (OpenTofu compatible).
*   **Configuration:** Ansible.
*   **State & Backups:** **Cloudflare R2** (S3-compatible).
    *   **Justification:** Zero egress fees and a generous free tier (10GB/mo) make it ideal for storing Terraform state files and Longhorn/Database backups securely.

### **Repository Structure**

```
samsara/                     # ♾️ Automation Root
  ├── terraform/
  │   ├── kshitiz/           # ☁️ Edge Layer (AWS Lightsail)
  │   │   └── main.tf        # Spawns Lighthouse & Static IP
  │   └── vyom/              # 🏠 Compute Layer (Proxmox VMs)
  │       └── main.tf        # Clones Cloud-Init templates to create K8s VMs
  │
  └── ansible/
      ├── inventory/
      │   ├── hosts.ini
      │   └── group_vars/
      │       ├── brahmanda/ # 🌏 Global vars (formerly 'all')
      │       ├── kshitiz/   # Edge specific
      │       └── vyom/      # Compute specific
      └── roles/
          ├── hardening      # CIS benchmark rules, UFW setup
          ├── k3s-setup      # Automates K3s cluster creation
          └── nebula         # Mesh networking setup
```

### **Workflow (The "Happy Path")**

1.  **Day 1 (Edge):** Run `terraform apply` in `samsara/terraform/kshitiz`. This provisions the Lightsail instance and outputs the Static IP.
2.  **Day 1 (Config):** Update `hosts.ini` with the new IP. Run the bootstrap playbook with secret injection:
    ```bash
    ansible-playbook playbooks/01-bootstrap-edge.yml --vault-password-file <(op read "op://Private/Ansible Vault - Samsara/password")
    ```
3.  **Day 2 (Compute):** Run `terraform apply` in `samsara/terraform/vyom`. This talks to the Proxmox API to clone and start the Ubuntu VMs on the NUC.
4.  **Day 2 (Cluster):** Bootstrap the Kubernetes cluster:
    ```bash
    ansible-playbook playbooks/02-bootstrap-cluster.yml --vault-password-file <(op read "op://Private/Ansible Vault - Samsara/password")
    ```

### **Scaling (Adding a Jetson)**

1.  Add the Jetson IP to `samsara/ansible/inventory/hosts.ini` under the `[vyom:children]` group (e.g., in a `gpu_nodes` subgroup).
2.  Ensure the specific Nebula certificate key is added to `group_vars/vyom/vault.yml`.
3.  Re-run the cluster playbook:
    ```bash
    ansible-playbook playbooks/02-bootstrap-cluster.yml --vault-password-file <(op read "op://Private/Ansible Vault - Samsara/password")
    ```
    Ansible will detect the new node, install Nebula, and join it to the existing K3s cluster automatically.

## **Homelab Security Hardening Strategy**

### **1. Network Segmentation (The "Air Gap")**

*   **Objective:** If the K8s cluster is compromised, the attacker is trapped.
*   **VLAN 10 (Home LAN):** Your family's phones, laptops.
*   **VLAN 20 (Mgmt):** Only your Laptop and the Proxmox Admin UI.
*   **VLAN 30 (DMZ):** The Kubernetes VMs exposed to the internet.
*   **Rule:** The DMZ VLAN cannot initiate connections to VLAN 10 or 20.
*   **Implementation:** In Proxmox Firewall (Datacenter level), set a default `DROP` policy for outgoing traffic from DMZ VMs to `192.168.1.0/24`.

### **2. Nebula Mesh Security**

*   **Groups:** Use Nebula's built-in firewall.
    *   `group:lighthouse` - Can only talk UDP/4242.
    *   `group:k8s-nodes` - Can talk TCP/6443 (API) to each other.
    *   `group:public-ingress` - The only group allowed to receive HTTP/80 traffic from the Lighthouse.
*   **Key Management:** Store your `ca.key` on an encrypted USB drive or secured in 1Password. Never put it on the servers.

### **3. Host Hardening (Proxmox & VMs)**

*   **SSH:** Disable password login (`PasswordAuthentication no`). Use SSH keys only.
*   **Fail2Ban:** Install on the Lightsail Gateway. Ban IPs after 3 failed attempts.
*   **Unprivileged Containers:** If running LXC, always check "Unprivileged". This maps `root` inside the container to a non-root user on the host, preventing container breakout attacks.

### **4. The "Kill Switch"**

*   Configure a cron job or a simple script on the Proxmox host that can instantly shut down the "Internet Gateway" VM or stop the Nebula service if you detect an anomaly.
