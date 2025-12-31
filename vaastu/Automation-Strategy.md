# **🤖 Infrastructure as Code (IaC) Plan**

## **Tooling Choices**

* **Provisioning:** Terraform (OpenTofu compatible).
* **Configuration:** Ansible.
* **State & Backups:** **Cloudflare R2** (S3-compatible).
  * **Justification:** Zero egress fees and a generous free tier (10GB/mo) make it ideal for storing Terraform state files and Longhorn/Database backups securely.

## **Repository Structure**

samsara/                     \# ♾️ Automation Root
  ├── terraform/
  │   ├── kshitiz/           \# ☁️ Edge Layer (AWS Lightsail)
  │   │   └── main.tf        \# Spawns Lighthouse & Static IP
  │   └── vyom/              \# 🏠 Compute Layer (Proxmox VMs)
  │       └── main.tf        \# Clones Cloud-Init templates to create K8s VMs
  │
  └── ansible/
      ├── inventory/
      │   ├── hosts.ini
      │   └── group\_vars/
      │       ├── brahmanda/ \# 🌏 Global vars (formerly 'all')
      │       ├── kshitiz/   \# Edge specific
      │       └── vyom/      \# Compute specific
      └── roles/
          ├── hardening      \# CIS benchmark rules, UFW setup
          ├── k3s-setup      \# Automates K3s cluster creation
          └── nebula         \# Mesh networking setup

## **Workflow (The "Happy Path")**

1. **Day 1 (Edge):** Run terraform apply in samsara/terraform/kshitiz. This provisions the Lightsail instance and outputs the Static IP.
2. Day 1 (Config): Update hosts.ini with the new IP. Run the bootstrap playbook with secret injection:
   ansible-playbook playbooks/01-bootstrap-edge.yml \--vault-password-file \<(op read "op://Private/Ansible Vault \- Samsara/password")
3. **Day 2 (Compute):** Run terraform apply in samsara/terraform/vyom. This talks to the Proxmox API to clone and start the Ubuntu VMs on the NUC.
4. Day 2 (Cluster): Bootstrap the Kubernetes cluster:
   ansible-playbook playbooks/02-bootstrap-cluster.yml \--vault-password-file \<(op read "op://Private/Ansible Vault \- Samsara/password")

## **Scaling (Adding a Jetson)**

1. Add the Jetson IP to samsara/ansible/inventory/hosts.ini under the \[vyom:children\] group (e.g., in a gpu\_nodes subgroup).
2. Ensure the specific Nebula certificate key is added to group\_vars/vyom/vault.yml.
3. Re-run the cluster playbook:
   ansible-playbook playbooks/02-bootstrap-cluster.yml \--vault-password-file \<(op read "op://Private/Ansible Vault \- Samsara/password")
   Ansible will detect the new node, install Nebula, and join it to the existing K3s cluster automatically.
