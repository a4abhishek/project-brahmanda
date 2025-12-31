# **RFC 003: Hybrid Secret Management Strategy (Project Samsara)**

Project Brahmanda requires the management of highly sensitive credentials (Nebula CA keys, SSH private keys, Cloud API tokens). Since the infrastructure spans multiple environments (MacBook, Windows/WSL, CI/CD pipelines) and manages the network layer itself, relying solely on an online-only secret manager creates a "Connectivity Paradox" (you cannot fetch the keys to fix the network if the network is down).

## **Decision**

We will adopt a **Hybrid Secret Management** model combining **Ansible Vault** and **1Password**.

1. **Storage (The Vault):**
   - All sensitive infrastructure secrets (e.g., ca.key, id_rsa) will be stored **encrypted at rest** within the Git repository using **Ansible Vault**.
   - We will use a **"Scoped Files, Single Key"** strategy. Secrets are split into separate files based on their domain (Global vs. Edge vs. Compute), but they are all encrypted with the same master password.
   - This ensures "Infrastructure as Code" integrity: rolling back a commit also rolls back the secrets associated with it.
2. **Access Control (The Key):**
   - The **Ansible Vault Password** itself will be stored securely in **1Password**.
   - It will **never** be written to disk in plain text.

## **Detailed Rationale**

### **1\. The Connectivity Paradox (Resilience)**

- **Problem:** If we relied purely on fetching secrets from 1Password via API (op run) during runtime, a Lighthouse failure or home internet outage would prevent us from running the Ansible playbooks needed to fix the outage.
- **Solution:** By storing the encrypted secrets locally in the git repo, we only need the _Vault Password_ to decrypt them. This password can be manually retrieved from the 1Password mobile app on a phone if the laptop has no internet, allowing for offline infrastructure repair.

### **2\. Cross-Platform Compatibility**

- The user operates on both **macOS** (Work) and **Windows/WSL** (Home).
- Ansible Vault files are just text files in Git; they sync seamlessly.
- 1Password handles the secure synchronization of the Vault Password across devices.

### **3\. CI/CD Integration**

- In automated pipelines (GitHub Actions), we do not need to expose the entire 1Password vault. We only need to inject the **Vault Password** as a GitHub Repository Secret. Ansible handles the rest locally within the runner.

## **Implementation Plan**

### **1\. Directory Structure (Scoped Vaults)**

samsara/
├── ansible/
│ ├── group_vars/
│ │ ├── brahmanda/ \# Universal/Global Secrets (Nebula CA Key, Admin Passwords)
│ │ │ ├── vault.yml
│ │ │ └── vars.yml
│ │ ├── kshitiz/ \# Edge Layer Secrets (Lighthouse)
│ │ │ └── vault.yml \# (e.g., Specific SSH Host Keys for Lightsail)
│ │ └── vyom/ \# Compute Layer Secrets (K8s Nodes/NUC)
│ │ └── vault.yml \# (e.g., K3s Tokens, Longhorn S3 Keys)

### **2\. Workflow (Local Development)**

- **Setup:** The SRE retrieves the Vault Password from 1Password once per session.
- **Execution:**
  \# Option A: Manual Entry (Offline mode)
  ansible-playbook setup.yml \--ask-vault-pass

  \# Option B: Automated (Online mode using 1Password CLI)
  \# The script fetches the password from 1Password and passes it to Ansible
  ansible-playbook setup.yml \--vault-password-file \<(op read "op://Private/Ansible Vault/password")

### **3\. Workflow (CI/CD)**

- Store the Vault Password in GitHub Secrets as ANSIBLE_VAULT_PASSWORD.
- Pipeline Step:
  \- name: Run Playbook
  run: |
  echo "$ANSIBLE_VAULT_PASSWORD" \> .vault_pass
  ansible-playbook site.yml \--vault-password-file .vault_pass
  rm .vault_pass
  env:
  ANSIBLE_VAULT_PASSWORD: ${{ secrets.ANSIBLE\_VAULT\_PASSWORD }}

## **Consequences**

- **Positive:** Full offline recovery capability. Secrets are version-controlled with code. Zero-trust regarding where the code is stored (repo can be public, secrets remain encrypted).
- **Negative:** High friction if the Vault Password is lost (data is unrecoverable). Binary blobs in git history if vault files change frequently (mitigated by keeping vault files small and specific).
